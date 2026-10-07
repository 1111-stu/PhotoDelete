#!/usr/bin/env python3
"""Small Swift string scanner shared by migration and localization validation.

It keeps comments, ordinary data strings and nested interpolation expressions
separate. Xcode's extracted strings remain the authority for interpolation types.
"""
import re
from dataclasses import dataclass

CJK = re.compile(r"[\u3400-\u9fff]")
FORMAT = re.compile(r"%(?:(\d+)\$)?([-+0 #]*\d*(?:\.\d+)?(?:lld|llu|ld|lu|@|d|i|u|f|g|s))")


def placeholders(value):
    # %% is a literal percent, not an argument.
    return [m for m in FORMAT.finditer(value) if len(re.search(r"%*$", value[:m.start()])[0]) % 2 == 0]


def source_format(value):
    matches = placeholders(value)
    order = [int(m[1] or i + 1) for i, m in enumerate(matches)]
    for m in reversed(matches):
        value = value[:m.start()] + '%' + m[2] + value[m.end():]
    return value, order


def remap_format(value, order):
    if order == list(range(1, len(order) + 1)):
        return value
    inverse = {old: new for new, old in enumerate(order, 1)}
    matches = placeholders(value)
    for i, m in reversed(list(enumerate(matches))):
        old = int(m[1] or i + 1)
        value = value[:m.start()] + f"%{inverse[old]}${m[2]}" + value[m.end():]
    return value


@dataclass
class Literal:
    start: int
    end: int
    parts: list  # alternating decoded text and (Swift expression,)

    @property
    def expressions(self):
        return [part[0] for part in self.parts if isinstance(part, tuple)]

    def pattern(self):
        return "".join("(?:" + FORMAT.pattern + ")" if isinstance(p, tuple) else re.escape(p.replace('%', '%%') if self.expressions else p) for p in self.parts)


def skip_comment(text, pos):
    if text.startswith("//", pos):
        end = text.find("\n", pos)
        return len(text) if end < 0 else end
    if text.startswith("/*", pos):
        depth, pos = 1, pos + 2
        while depth and pos < len(text):
            if text.startswith("/*", pos):
                depth, pos = depth + 1, pos + 2
            elif text.startswith("*/", pos):
                depth, pos = depth - 1, pos + 2
            else:
                pos += 1
        return pos
    return pos


def expression_end(text, pos):
    depth = 1
    while pos < len(text):
        end = skip_comment(text, pos)
        if end != pos:
            pos = end
        elif text[pos] == '"':
            pos = read_literal(text, pos)[0].end
        elif text[pos] == '(':
            depth, pos = depth + 1, pos + 1
        elif text[pos] == ')':
            depth -= 1
            if not depth:
                return pos
            pos += 1
        else:
            pos += 1
    raise ValueError("Unclosed Swift interpolation")


def read_literal(text, start):
    # This repository uses ordinary single-line literals. Reject new syntax
    # rather than quietly rewriting raw or multiline string contents.
    if text.startswith('"""', start) or (start and text[start - 1] == '#'):
        raise ValueError("Raw/multiline literals need an explicit scanner extension")
    pos, chunk, parts, children = start + 1, "", [], []
    escapes = {'n': '\n', 'r': '\r', 't': '\t', '0': '\0', '"': '"', "'": "'", '\\': '\\'}
    while pos < len(text):
        ch = text[pos]
        if ch == '"':
            parts.append(chunk)
            return Literal(start, pos + 1, parts), children
        if ch == '\\':
            if text[pos + 1] == '(':
                end = expression_end(text, pos + 2)
                parts.extend([chunk, (text[pos + 2:end],)])
                children.extend(scan_literals(text[pos + 2:end], offset=pos + 2))
                chunk, pos = "", end + 1
                continue
            if text[pos + 1] == 'u' and text[pos + 2] == '{':
                end = text.index('}', pos + 3)
                chunk += chr(int(text[pos + 3:end], 16))
                pos = end + 1
                continue
            chunk += escapes[text[pos + 1]]
            pos += 2
        else:
            chunk += ch
            pos += 1
    raise ValueError("Unclosed Swift string")


def scan_literals(text, offset=0):
    result, pos = [], 0
    while pos < len(text):
        end = skip_comment(text, pos)
        if end != pos:
            pos = end
        elif text[pos] == '"':
            literal, children = read_literal(text, pos)
            end = literal.end
            literal.start += offset
            literal.end += offset
            for child in children:
                child.start += offset
                child.end += offset
            result.extend([literal, *children])
            pos = end
        else:
            pos += 1
    return result


def localization_context(text, literal):
    prefix = text[:literal.start]
    if re.search(r'L10n\.(?:string|key|attributedMarkdown)\(\s*$', prefix):
        return 'lookup'
    calls = list(re.finditer(r'L10n\.(?:string|key|attributedMarkdown)\(', prefix))
    if calls and literal.start < expression_end(text, calls[-1].end()):
        return 'lookup'
    if re.search(r'(?:titleKey|subtitleKey|summaryKey):\s*$', prefix):
        return 'dynamic'
    if re.search(r'(?:Text|Label|Button|Toggle|Picker|navigationTitle|accessibilityLabel|accessibilityHint)\(\s*$', prefix):
        return 'swiftui'
    return None


def swift_quote(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t') + '"'


def interpolated_quote(template, expressions):
    result, previous = '"', 0
    for i, m in enumerate(placeholders(template)):
        result += swift_quote(template[previous:m.start()].replace('%%', '%'))[1:-1]
        result += '\\(' + expressions[i] + ')'
        previous = m.end()
    return result + swift_quote(template[previous:].replace('%%', '%'))[1:-1] + '"'
