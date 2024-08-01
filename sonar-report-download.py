import json
import sys
import os

def parse_issue(issue):
    return {
        "Key": issue.get("key"),
        "Rule": issue.get("rule"),
        "Severity": issue.get("severity"),
        "Component": issue.get("component"),
        "Project": issue.get("project"),
        "Line": issue.get("line"),
        "Message": issue.get("message"),
        "Effort": issue.get("effort"),
        "Debt": issue.get("debt"),
        "Author": issue.get("author"),
        "Tags": ", ".join(issue.get("tags", [])),
        "CreationDate": issue.get("creationDate"),
        "UpdateDate": issue.get("updateDate"),
        "Type": issue.get("type"),
        "Status": issue.get("status"),
    }

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 json_to_human_readable.py <input_json_file> <output_text_file>")
        return

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.exists(input_file):
        print(f"Input file {input_file} does not exist.")
        return

    with open(input_file, "r") as f:
        data = json.load(f)

    issues = data.get("issues", [])
    parsed_issues = [parse_issue(issue) for issue in issues]

    with open(output_file, "w") as f:
        for issue in parsed_issues:
            for key, value in issue.items():
                f.write(f"{key}: {value}\n")
            f.write("\n")

    print(f"Human-readable report saved to {output_file}")

if __name__ == "__main__":
    main()

