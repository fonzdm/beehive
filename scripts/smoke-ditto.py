"""Disposable relay transport/auth smoke test; pip install coincurve websockets.

Usage: python smoke-ditto.py CONNECTION_URL [PUBLIC_RELAY_URL]
Publishes one synthetic kind-1059 envelope expiring in five minutes. This tests
relay access rules, not client encryption or the full Armada/Amber UI.
"""
import asyncio
import hashlib
import json
import secrets
import sys
import time
from coincurve import PrivateKey
from websockets.asyncio.client import connect

URL = sys.argv[1]
PUBLIC_URL = sys.argv[2] if len(sys.argv) > 2 else URL

def pub(key):
    return key.public_key_xonly.format().hex()

def event(key, kind, tags, content=""):
    e = dict(pubkey=pub(key), created_at=int(time.time()), kind=kind, tags=tags, content=content)
    raw = json.dumps([0, e['pubkey'], e['created_at'], kind, tags, content], separators=(',', ':'), ensure_ascii=False)
    digest = hashlib.sha256(raw.encode()).digest()
    return dict(e, id=digest.hex(), sig=key.sign_schnorr(digest).hex())

async def send(ws, *message):
    await ws.send(json.dumps(message))

async def until(ws, kind, subscription=None):
    async with asyncio.timeout(15):
        while True:
            message = json.loads(await ws.recv())
            if message[0] == kind and (subscription is None or message[1] == subscription):
                return message

async def main():
    recipient, outer, stranger = PrivateKey(), PrivateKey(), PrivateKey()
    envelope = event(outer, 1059, [['p', pub(recipient)], ['expiration', str(int(time.time()) + 300)]], secrets.token_hex(64))
    async with connect(URL) as publisher, connect(URL) as stream, connect(URL) as inbox:
        await send(stream, 'REQ', 'stream', dict(kinds=[1059], authors=[pub(outer)]))
        await until(stream, 'EOSE', 'stream')
        await send(inbox, 'REQ', 'blocked', {'kinds': [1059], '#p': [pub(recipient)]})
        # Challenge and CLOSED order is not specified by NIP-42.
        challenge = None
        closed = None
        async with asyncio.timeout(15):
            while not challenge or not closed:
                m = json.loads(await inbox.recv())
                if m[0] == 'AUTH': challenge = m[1]
                if m[0] == 'CLOSED': closed = m
        assert 'auth-required:' in closed[2], closed
        await send(inbox, 'AUTH', event(recipient, 22242, [['relay', PUBLIC_URL], ['challenge', challenge]]))
        assert (await until(inbox, 'OK'))[2] is True
        await send(inbox, 'REQ', 'inbox', {'kinds': [1059], '#p': [pub(recipient)]})
        await until(inbox, 'EOSE', 'inbox')
        await send(publisher, 'EVENT', envelope)
        assert (await until(publisher, 'OK'))[2] is True
        assert (await until(stream, 'EVENT', 'stream'))[2]['id'] == envelope['id']
        assert (await until(inbox, 'EVENT', 'inbox'))[2]['id'] == envelope['id']
        print('PASS: anonymous recipient query denied; NIP-42 recipient and Concord author stream receive live events')
        await asyncio.sleep(3)
        await send(stream, 'REQ', 'history', dict(kinds=[1059], authors=[pub(outer)]))
        assert (await until(stream, 'EVENT', 'history'))[2]['id'] == envelope['id']
        await send(inbox, 'REQ', 'wrong-recipient', {'kinds': [1059], '#p': [pub(stranger)]})
        denial = await until(inbox, 'CLOSED')
        assert denial[2].startswith(('restricted:', 'auth-required:')), denial
        print('PASS: Concord author history works; authenticated identity cannot query another recipient')
        transport = event(stranger, 24133, [['p', pub(outer)]], secrets.token_hex(32))
        await send(stream, 'REQ', 'bunker', {'kinds': [24133], '#p': [pub(outer)]})
        await until(stream, 'EOSE', 'bunker')
        await send(publisher, 'EVENT', transport)
        assert (await until(publisher, 'OK'))[2] is True
        assert (await until(stream, 'EVENT', 'bunker'))[2]['id'] == transport['id']
        print('PASS: anonymous NIP-46 transport pub/sub works')

asyncio.run(main())
