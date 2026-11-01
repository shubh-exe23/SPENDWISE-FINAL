import os
import sys
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

# Override before app/config import; no financial database or scheduler is used.
os.environ['DATABASE_URL'] = 'sqlite://'
os.environ['JWT_SECRET_KEY'] = 'isolated-test-key-that-is-never-used-in-production-123456'
os.environ['ENABLE_SCHEDULER'] = 'false'
os.environ['RESET_STORE_URL'] = ''
os.environ['CORS_ORIGINS'] = 'https://frontend.example'
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import app, scheduler
from flask_jwt_extended import create_access_token
from models.database import db
from models.transaction import Transaction
from models.user import User


class FrozenDateTime(datetime):
    @classmethod
    def now(cls, tz=None):
        return cls(2026, 10, 14, 12)

    @classmethod
    def utcnow(cls):
        return cls.now()


class ClearTransactionsTests(unittest.TestCase):
    endpoints = ('/api/transactions/clear', '/transactions/clear')
    dates = {
        'previous_month': '2026-09-30T23:59:59.999999',
        'month_start': '2026-10-01T00:00:00',
        'previous_week': '2026-10-10T23:59:59.999999',
        'sunday': '2026-10-11T00:00:00',
        'monday': '2026-10-12T00:00:00',
        'yesterday_start': '2026-10-13T00:00:00',
        'yesterday_end': '2026-10-13T23:59:59.999999',
        'today_start': '2026-10-14T00:00:00',
        'today_noon': '2026-10-14T12:00:00',
    }

    def setUp(self):
        app.config['TESTING'] = True
        self.context = app.app_context()
        self.context.push()
        self.assertEqual(str(db.engine.url), 'sqlite://')
        self.assertFalse(scheduler.running)
        db.create_all()
        db.session.add_all([User(id=i, email=f'user{i}@example.invalid', password='test') for i in (1, 2)])
        db.session.commit()
        self.headers = {'Authorization': 'Bearer ' + create_access_token(identity='1')}
        self.client = app.test_client()
        self.patches = [patch('app.datetime', FrozenDateTime), patch('routes.transactions.datetime', FrozenDateTime)]
        for item in self.patches:
            item.start()

    def tearDown(self):
        for item in self.patches:
            item.stop()
        db.session.remove()
        db.drop_all()
        self.context.pop()

    def seed(self, future=False):
        db.session.remove()
        Transaction.query.delete()
        dates = dict(self.dates)
        if future:
            dates['future'] = '2026-11-01T00:00:00'
        for owner in (1, 2):
            for label, date in dates.items():
                db.session.add(Transaction(title=label, amount=1, category='Test',
                                           date=datetime.fromisoformat(date), user_id=owner))
        db.session.commit()
        return set(dates)

    def rows(self, owner):
        db.session.expire_all()
        return {row.title for row in Transaction.query.filter_by(user_id=owner).all()}

    def clear(self, endpoint, period):
        kwargs = {'query_string': {'period': period}} if endpoint == self.endpoints[0] else {'json': {'period': period}}
        return self.client.delete(endpoint, headers=self.headers, **kwargs)

    def test_all_periods_and_normalization(self):
        expected = {
            'Today': {'today_start', 'today_noon'},
            'Yesterday': {'yesterday_start', 'yesterday_end'},
            'This week': {'monday', 'yesterday_start', 'yesterday_end', 'today_start', 'today_noon'},
            'This month': set(self.dates) - {'previous_month'},
            'All time': set(self.dates),
        }
        for endpoint in self.endpoints:
            for period, deleted in expected.items():
                for value in (period, period.upper(), ' \t' + period.lower() + ' \n'):
                    with self.subTest(endpoint=endpoint, period=value):
                        all_rows = self.seed()
                        target = deleted | {'sunday'} if period == 'This week' and endpoint == self.endpoints[1] else deleted
                        response = self.clear(endpoint, value)
                        self.assertEqual(response.status_code, 200)
                        self.assertEqual(self.rows(1), all_rows - target)
                        self.assertEqual(self.rows(2), all_rows)
                        if endpoint == self.endpoints[0]:
                            self.assertEqual(response.json, {'message': f'Cleared {len(target)} transactions for {value}'})
                        else:
                            self.assertEqual(response.json, {'message': 'success', 'deleted_count': len(target)})

    def test_invalid_periods_do_not_delete(self):
        for endpoint in self.endpoints:
            for value in ('', '  ', 'null', 'undefined', 'Custom', 'Last week', 'all', 'This weeks', None, 0, False, [], {}):
                with self.subTest(endpoint=endpoint, value=value):
                    all_rows = self.seed()
                    response = self.clear(endpoint, value)
                    self.assertEqual(response.status_code, 400)
                    self.assertIn('error', response.json)
                    for owner in (1, 2):
                        self.assertEqual(self.rows(owner), all_rows)

    def test_missing_malformed_and_wrong_request_format(self):
        cases = [
            (self.endpoints[0], {}),
            (self.endpoints[0], {'json': {'period': 'All time'}}),
            (self.endpoints[1], {}),
            (self.endpoints[1], {'json': {}}),
            (self.endpoints[1], {'query_string': {'period': 'All time'}}),
        ]
        for body in ('null', '[]', '"All time"', '42', '{invalid', '{"period":'):
            cases.append((self.endpoints[1], {'data': body, 'content_type': 'application/json'}))
        for endpoint, kwargs in cases:
            with self.subTest(endpoint=endpoint, kwargs=kwargs):
                all_rows = self.seed()
                response = self.client.delete(endpoint, headers=self.headers, **kwargs)
                self.assertEqual(response.status_code, 400)
                for owner in (1, 2):
                    self.assertEqual(self.rows(owner), all_rows)

    def test_jwt_still_required(self):
        for endpoint in self.endpoints:
            all_rows = self.seed()
            response = self.client.delete(endpoint, query_string={'period': 'All time'}, json={'period': 'All time'})
            self.assertEqual(response.status_code, 401)
            for owner in (1, 2):
                self.assertEqual(self.rows(owner), all_rows)

    def test_existing_open_ended_ranges_preserved(self):
        for endpoint in self.endpoints:
            for period in ('Today', 'Yesterday', 'This week', 'This month'):
                with self.subTest(endpoint=endpoint, period=period):
                    all_rows = self.seed(future=True)
                    self.assertEqual(self.clear(endpoint, period).status_code, 200)
                    self.assertEqual('future' in self.rows(1), period == 'Yesterday')
                    self.assertEqual(self.rows(2), all_rows)


if __name__ == '__main__':
    unittest.main()
