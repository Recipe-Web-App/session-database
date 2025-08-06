#!/usr/bin/env python3
# scripts/jobHelpers/parse-cleanup-results.py
# Parse and log session cleanup results from stdin

import json
import sys

try:
    data = json.load(sys.stdin)
    print(f'Sessions cleaned: {data.get("sessions_cleaned", 0)}')
    print(f'Refresh tokens cleaned: {data.get("refresh_tokens_cleaned", 0)}')
    print(f'Deletion tokens cleaned: {data.get("deletion_tokens_cleaned", 0)}')
    print(f'Errors: {data.get("errors", 0)}')

    # Exit with error if there were issues
    if data.get('errors', 0) > 0:
        sys.exit(1)
except Exception as e:
    print(f'Error parsing cleanup results: {e}')
    sys.exit(1)
