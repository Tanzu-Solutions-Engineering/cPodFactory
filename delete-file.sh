#!/bin/bash
#bdereims@vmware.com

git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch grease-monkey.ova' \
  --prune-empty --tag-name-filter cat -- --all
