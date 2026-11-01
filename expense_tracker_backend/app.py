import os
import hmac
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager, jwt_required, get_jwt_identity
from config import Config
from models.database import db
from datetime import datetime, timedelta
from routes.subscriptions import subscriptions_bp
from apscheduler.schedulers.background import BackgroundScheduler
from cron import check_and_process_subscriptions
from routes.magic import magic_bp
from routes.categories import categories_bp
from routes.outings import outings_bp
from routes.analysis import analysis_bp

app = Flask(__name__)
app.config.from_object(Config)

CORS(app, origins=app.config["CORS_ORIGINS"])
JWTManager(app)
db.init_app(app)

# ── START THE SUBSCRIPTION AUTOMATOR ──
scheduler = BackgroundScheduler()

# For PRODUCTION: Check once every 24 hours
scheduler.add_job(func=lambda: check_and_process_subscriptions(app), trigger="interval", hours=24)

# FOR TESTING TODAY: Uncomment the line below to make it check every 1 minute!
#scheduler.add_job(func=lambda: check_and_process_subscriptions(app), trigger="interval", minutes=1)

if not os.getenv("VERCEL") and os.getenv("ENABLE_SCHEDULER", "true").lower() == "true":
    scheduler.start()

# import models explicitly here
from models.user         import User
from models.transaction  import Transaction
from models.goal         import Goal
from models.notification import Notification

@app.after_request
def private_responses(response):
    response.headers['Cache-Control'] = 'private, no-store'#This block adds security-related headers to outgoing Flask responses to reduce unwanted caching and browser content-type guessing.
    response.headers['X-Content-Type-Options'] = 'nosniff'
    return response

@app.get('/internal/cron/subscriptions')
def scheduled_subscriptions():
    secret = os.getenv('CRON_SECRET', '')
    supplied = request.headers.get('Authorization', '')
    if not secret or not hmac.compare_digest(supplied, 'Bearer ' + secret):
        return {'error': 'Unauthorized'}, 401
    check_and_process_subscriptions(app)
    return {'status': 'ok'}, 200

@app.get('/healthz')
def healthz():
    return {'status': 'ok'}, 200

@app.route('/')
def index():
    return {'message': 'Expense Tracker API is running!'}, 200

@app.route('/api/transactions/clear', methods=['DELETE'])
@jwt_required()
def clear_transactions():
    user_id = get_jwt_identity()
    period = request.args.get('period')
    normalized_period = period.strip().lower() if isinstance(period, str) else None
    if normalized_period not in {'today', 'yesterday', 'this week', 'this month', 'all time'}:
        return jsonify({'error': 'A valid period is required'}), 400
    
    now = datetime.utcnow()
    
    # Start the base SQLAlchemy query for this user
    query = Transaction.query.filter_by(user_id=user_id)
    
    if normalized_period == 'today':
        start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
        query = query.filter(Transaction.date >= start_of_day)
    elif normalized_period == 'yesterday':
        yesterday_start = (now - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        yesterday_end = now.replace(hour=0, minute=0, second=0, microsecond=0)
        query = query.filter(Transaction.date >= yesterday_start, Transaction.date < yesterday_end)
    elif normalized_period == 'this week':
        start_of_week = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
        query = query.filter(Transaction.date >= start_of_week)
    elif normalized_period == 'this month':
        start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        query = query.filter(Transaction.date >= start_of_month)
    # Only an explicitly validated 'all time' may keep the query unrestricted by date.

    # Execute the delete and commit to PostgreSQL
    deleted_count = query.delete()
    db.session.commit()
    
    return jsonify({"message": f"Cleared {deleted_count} transactions for {period}"}), 200

from routes.auth          import auth_bp
from routes.transactions  import transactions_bp
from routes.goals         import goals_bp
from routes.notifications import notifications_bp

app.register_blueprint(auth_bp,url_prefix='/auth')
app.register_blueprint(transactions_bp)
app.register_blueprint(goals_bp)
app.register_blueprint(notifications_bp)
app.register_blueprint(subscriptions_bp)
app.register_blueprint(magic_bp, url_prefix='/api/magic')
app.register_blueprint(categories_bp)
app.register_blueprint(outings_bp)
app.register_blueprint(analysis_bp)

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        print('Database created successfully')
    app.run(host='0.0.0.0', port=5000, debug=True)