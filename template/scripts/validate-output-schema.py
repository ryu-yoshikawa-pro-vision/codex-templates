#!/usr/bin/env python3
import json
import math
import sys
from pathlib import Path

SUPPORTED_SCHEMA_KEYS = {
    "$schema",
    "$defs",
    "$ref",
    "title",
    "description",
    "type",
    "enum",
    "minLength",
    "minimum",
    "required",
    "properties",
    "items",
    "additionalProperties",
}


def load_json(path_str):
    path = Path(path_str)
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"Missing JSON file: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}")


def check_type(expected, value):
    if isinstance(expected, list):
        return any(check_type(item, value) for item in expected)
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        if isinstance(value, bool):
            return False
        return isinstance(value, (int, float)) and not math.isnan(value)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "null":
        return value is None
    return True


def resolve_json_pointer(root_schema, ref):
    if not ref.startswith("#/"):
        raise ValueError(f"Unsupported $ref target: {ref}")

    current = root_schema
    for raw_part in ref[2:].split("/"):
        part = raw_part.replace("~1", "/").replace("~0", "~")
        if not isinstance(current, dict) or part not in current:
            raise ValueError(f"Unresolvable $ref target: {ref}")
        current = current[part]
    return current


def resolve_schema(schema, root_schema):
    if "$ref" not in schema:
        return schema

    target = resolve_json_pointer(root_schema, schema["$ref"])
    if not isinstance(target, dict):
        raise ValueError(f"$ref target must resolve to an object: {schema['$ref']}")

    merged = dict(target)
    for key, value in schema.items():
        if key != "$ref":
            merged[key] = value
    return merged


def validate(schema, value, path, errors, root_schema):
    try:
        schema = resolve_schema(schema, root_schema)
    except ValueError as exc:
        errors.append(f"{path}: {exc}")
        return

    expected = schema.get("type")
    if expected and not check_type(expected, value):
        errors.append(f"{path}: expected {expected}, got {type(value).__name__}")
        return

    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: value {value!r} not in enum {schema['enum']!r}")

    if isinstance(value, str) and "minLength" in schema and len(value) < schema["minLength"]:
        errors.append(f"{path}: expected minLength {schema['minLength']}, got {len(value)}")

    if isinstance(value, (int, float)) and not isinstance(value, bool) and "minimum" in schema and value < schema["minimum"]:
        errors.append(f"{path}: expected minimum {schema['minimum']}, got {value}")

    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                errors.append(f"{path}: missing required property '{key}'")

        properties = schema.get("properties", {})
        for key, subschema in properties.items():
            if key in value:
                validate(subschema, value[key], f"{path}.{key}", errors, root_schema)

        if schema.get("additionalProperties") is False:
            extra = sorted(set(value.keys()) - set(properties.keys()))
            for key in extra:
                errors.append(f"{path}: unexpected property '{key}'")

    if isinstance(value, list) and "items" in schema:
        for idx, item in enumerate(value):
            validate(schema["items"], item, f"{path}[{idx}]", errors, root_schema)


def collect_unsupported_keywords(schema, path, errors):
    if isinstance(schema, dict):
        unsupported = sorted(set(schema.keys()) - SUPPORTED_SCHEMA_KEYS)
        for key in unsupported:
            errors.append(f"{path}: unsupported schema keyword '{key}'")

        if "$defs" in schema and isinstance(schema["$defs"], dict):
            for key, subschema in schema["$defs"].items():
                collect_unsupported_keywords(subschema, f"{path}.$defs.{key}", errors)

        if "properties" in schema and isinstance(schema["properties"], dict):
            for key, subschema in schema["properties"].items():
                collect_unsupported_keywords(subschema, f"{path}.properties.{key}", errors)

        if "items" in schema:
            collect_unsupported_keywords(schema["items"], f"{path}.items", errors)
    elif isinstance(schema, list):
        for idx, item in enumerate(schema):
            collect_unsupported_keywords(item, f"{path}[{idx}]", errors)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: validate-output-schema.py <schema.json> <output.json>")

    schema = load_json(sys.argv[1])
    output = load_json(sys.argv[2])
    errors = []
    collect_unsupported_keywords(schema, "$", errors)
    validate(schema, output, "$", errors, schema)
    if errors:
        raise SystemExit("\n".join(errors))


if __name__ == "__main__":
    main()
