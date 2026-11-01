from models.database import db
from datetime import datetime

class Subscription(db.Model):
    __tablename__ = 'subscriptions'

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    amount = db.Column(db.Float, nullable=False)
    is_expense = db.Column(db.Boolean, default=True)
    category = db.Column(db.String(50), nullable=False)
    payment_method = db.Column(db.String(50), default='Cash')
    frequency = db.Column(db.String(20), default='monthly')
    next_billing_date = db.Column(db.DateTime, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'amount': self.amount,
            'is_expense': self.is_expense,
            'category': self.category,
            'payment_method': self.payment_method,
            'frequency': self.frequency,
            'next_billing_date': self.next_billing_date.isoformat(),
        }