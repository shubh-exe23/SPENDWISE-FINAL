import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

# Never use production data. Set these before importing config/app or loading .env.
os.environ['DATABASE_URL'] = 'sqlite://'
os.environ['JWT_SECRET_KEY'] = 'isolated-test-key-that-is-never-used-in-production-123456'
os.environ['ENABLE_SCHEDULER'] = 'false'
os.environ['RESET_STORE_URL'] = ''
os.environ['CORS_ORIGINS'] = 'https://frontend.example'
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import app, scheduler
from models.database import db

class DeploymentTests(unittest.TestCase):
    def setUp(self):
        app.config['TESTING'] = True
        self.context = app.app_context()
        self.context.push()
        self.assertEqual(str(db.engine.url), 'sqlite://')
        db.create_all()
        self.client = app.test_client()
        self.assertEqual(self.client.post('/auth/register', json={
            'email': 'deployment@example.invalid', 'password': 'test-only-password', 'name': 'Deployment Test'
        }).status_code, 201)
        result = self.client.post('/auth/login', json={
            'email': 'deployment@example.invalid', 'password': 'test-only-password'
        })
        self.assertEqual(result.status_code, 200)
        self.headers = {'Authorization': 'Bearer ' + result.json['token']}

    def tearDown(self):
        db.session.remove()
        db.drop_all()
        self.context.pop()

    def test_auth_health_and_private_cache(self):
        self.assertFalse(scheduler.running)
        self.assertEqual(self.client.get('/healthz').status_code, 200)
        self.assertEqual(self.client.get('/transactions').status_code, 401)
        response = self.client.get('/auth/profile', headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertIn('no-store', response.headers['Cache-Control'])
        self.assertEqual(self.client.post('/auth/login', json={
            'email': 'deployment@example.invalid', 'password': 'wrong'
        }).status_code, 401)

    def test_expense_crud_and_dashboard_reads(self):
        response = self.client.post('/transactions', headers=self.headers, json={
            'title': 'Migration test', 'amount': 12.5, 'category': 'Food',
            'date': '2026-09-30T12:00:00', 'is_expense': True, 'payment_method': 'Cash'
        })
        self.assertEqual(response.status_code, 201)
        ident = response.json['id']
        response = self.client.put(f'/transactions/{ident}', headers=self.headers, json={'amount': 15})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json['amount'], 15)
        for path in ['/transactions', '/goals', '/notifications', '/subscriptions', '/categories', '/outings']:
            self.assertEqual(self.client.get(path, headers=self.headers).status_code, 200, path)
        self.assertEqual(self.client.delete(f'/transactions/{ident}', headers=self.headers).status_code, 200)
        self.assertEqual(self.client.get('/transactions', headers=self.headers).json, [])
        self.assertEqual(self.client.get('/analysis/insights', headers=self.headers).status_code, 200)

    def test_cors_allowlist(self):
        allowed = self.client.options('/transactions', headers={
            'Origin': 'https://frontend.example', 'Access-Control-Request-Method': 'POST',
            'Access-Control-Request-Headers': 'Authorization,Content-Type'
        })
        self.assertEqual(allowed.headers.get('Access-Control-Allow-Origin'), 'https://frontend.example')
        denied = self.client.get('/healthz', headers={'Origin': 'https://untrusted.example'})
        self.assertIsNone(denied.headers.get('Access-Control-Allow-Origin'))

class ServerlessTests(unittest.TestCase):
    def setUp(self):
        self.context = app.app_context()
        self.context.push()
        import reset_store
        reset_store._local.clear()

    def tearDown(self):
        self.context.pop()

    def test_reset_expiry_replay_and_attempt_limit(self):
        import reset_store as store
        with patch.dict(os.environ, {'VERCEL': '', 'RESET_STORE_URL': ''}):
            code = store.issue_code('test@example.invalid')
            self.assertTrue(store.consume_code('test@example.invalid', code))
            self.assertFalse(store.consume_code('test@example.invalid', code))
            with patch('reset_store.time.time', return_value=100):
                code = store.issue_code('test@example.invalid')
            with patch('reset_store.time.time', return_value=701):
                self.assertFalse(store.consume_code('test@example.invalid', code))
            code = store.issue_code('test@example.invalid')
            wrong = '000000' if code != '000000' else '999999'
            for _ in range(5):
                self.assertFalse(store.consume_code('test@example.invalid', wrong))
            self.assertFalse(store.consume_code('test@example.invalid', code))

    def test_serverless_store_is_required_and_shared(self):
        import reset_store as store
        with patch.dict(os.environ, {'VERCEL': '1', 'RESET_STORE_URL': ''}):
            with self.assertRaises(RuntimeError):
                store.issue_code('test@example.invalid')
        with patch.dict(os.environ, {'VERCEL': '1', 'RESET_STORE_URL': 'https://frontend.example/internal/reset-codes', 'RESET_STORE_SECRET': 'test-secret'}):
            with patch('reset_store.requests.post') as post:
                post.return_value.json.return_value = {'ok': True}
                code = store.issue_code('test@example.invalid')
                store._local.clear()
                self.assertTrue(store.consume_code('test@example.invalid', code))
                first, second = post.call_args_list
                self.assertEqual(first.kwargs['json']['digest'], second.kwargs['json']['digest'])
                self.assertNotIn(code, str(first.kwargs['json']))
                self.assertNotIn('test@example.invalid', str(first.kwargs['json']))
                self.assertEqual(second.kwargs['headers']['Authorization'], 'Bearer test-secret')

    def test_cron_requires_secret_and_calls_existing_job(self):
        client = app.test_client()
        with patch.dict(os.environ, {'CRON_SECRET': 'test-cron-secret'}), patch('app.check_and_process_subscriptions') as job:
            self.assertEqual(client.get('/internal/cron/subscriptions').status_code, 401)
            self.assertEqual(client.get('/internal/cron/subscriptions', headers={'Authorization': 'Bearer wrong'}).status_code, 401)
            job.assert_not_called()
            self.assertEqual(client.get('/internal/cron/subscriptions', headers={'Authorization': 'Bearer test-cron-secret'}).status_code, 200)
            job.assert_called_once_with(app)

if __name__ == '__main__':
    unittest.main()
