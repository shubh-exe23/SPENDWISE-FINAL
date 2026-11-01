"""Temporary reset-code storage; shared on serverless, in-memory for local runs."""
import hashlib
import hmac
import os
import secrets
import time
from threading import Lock

import requests
from flask import current_app

_local = {}
_lock = Lock()

def _payload(email, code):
    key = hashlib.sha256(email.encode()).hexdigest()
    digest = hmac.new(current_app.config['JWT_SECRET_KEY'].encode(),
                      (email + ':' + str(code)).encode(), hashlib.sha256).hexdigest()
    return key, digest

def _exchange(action, email, code):
    key, digest = _payload(email, code)
    url = os.getenv('RESET_STORE_URL', '')
    if url:
        secret = os.environ['RESET_STORE_SECRET']
        response = requests.post(url, json={'action': action, 'key': key, 'digest': digest},
                                 headers={'Authorization': 'Bearer ' + secret}, timeout=10)
        response.raise_for_status()
        return response.json()['ok']
    if os.getenv('VERCEL'):
        raise RuntimeError('Shared reset-code store is required on Vercel')
    with _lock:
        if action == 'issue':
            _local[key] = {'digest': digest, 'expires': time.time() + 600, 'attempts': 0}
            return True
        entry = _local.get(key)
        if not entry:
            return False
        if entry['expires'] <= time.time():
            _local.pop(key, None)
            return False
        valid = hmac.compare_digest(entry['digest'], digest)
        entry['attempts'] += 1
        if valid or entry['attempts'] >= 5:
            _local.pop(key, None)
        return valid

def issue_code(email):
    code = str(100000 + secrets.randbelow(900000))
    _exchange('issue', email, code)
    return code

def consume_code(email, code):
    if not isinstance(code, str) or len(code) != 6 or not code.isascii() or not code.isdigit():
        return False
    return _exchange('consume', email, code)
