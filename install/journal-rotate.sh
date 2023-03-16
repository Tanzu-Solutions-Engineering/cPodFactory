#!/bin/bash
#bdereims@vmware.com

journalctl --rotate ; journalctl --vacuum-time=2h
#journalctl --rotate --vacuum-size=500M
