from datetime import datetime
import calendar
from sqlalchemy import text
from models.database import db
from models.subscriptions import Subscription
from models.transaction import Transaction
from models.notification import Notification

def add_months(sourcedate, months):
    """Helper function to safely add a month to a date (handling shorter months)."""
    month = sourcedate.month - 1 + months
    year = sourcedate.year + month // 12
    month = month % 12 + 1
    day = min(sourcedate.day, calendar.monthrange(year, month)[1])
    return sourcedate.replace(year=year, month=month, day=day)

def check_and_process_subscriptions(app):
    """Wakes up, checks for due bills, logs them, and notifies the user."""
    with app.app_context():
        # Serialize overlapping serverless invocations without adding tables.
        if db.engine.dialect.name == 'postgresql':
            locked = db.session.execute(text('SELECT pg_try_advisory_xact_lock(1936744819)')).scalar()
            if not locked:
                return
        today = datetime.utcnow()
        
        # 1. Find all subscriptions where the date is TODAY or in the past
        due_subs = Subscription.query.filter(Subscription.next_billing_date <= today).all()
        
        if not due_subs:
            return

        for sub in due_subs:
            # 2. Log the actual Transaction so it appears on their Dashboard
            new_txn = Transaction(
                title=f"{sub.title} (Auto-Billed)",
                amount=sub.amount,
                is_expense=sub.is_expense,
                date=today, # Log it for today
                category=sub.category,
                payment_method=sub.payment_method,
                user_id=sub.user_id
            )
            db.session.add(new_txn)
            
            # 3. Create a Notification for the user (using your exact model schema!)
            new_notif = Notification(
                title="Recurring Bill Paid 🔄",
                message=f"Your {sub.frequency} bill for {sub.title} (₹{sub.amount}) was automatically logged.",
                type="alert", 
                user_id=sub.user_id
            )
            db.session.add(new_notif)
            
            # 4. Fast-forward the next_billing_date so it doesn't trigger again tomorrow
            if sub.frequency == 'monthly':
                sub.next_billing_date = add_months(sub.next_billing_date, 1)
            else: # yearly
                try:
                    sub.next_billing_date = sub.next_billing_date.replace(year=sub.next_billing_date.year + 1)
                except ValueError:
                    # Edge case: Leap year (Feb 29) to a non-leap year becomes Feb 28
                    sub.next_billing_date = sub.next_billing_date.replace(year=sub.next_billing_date.year + 1, day=28)
                    
        db.session.commit()
        print(f"✅ SYSTEM: Processed {len(due_subs)} auto-subscriptions today!")