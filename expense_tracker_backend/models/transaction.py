from models.database import db
from datetime import datetime

class Transaction(db.Model):
    __tablename__ = 'transactions'

    id             = db.Column(db.Integer, primary_key=True)
    title          = db.Column(db.String(100), nullable=False)
    amount         = db.Column(db.Float,       nullable=False)
    is_expense     = db.Column(db.Boolean,     default=True)
    date           = db.Column(db.DateTime,    nullable=False)
    category       = db.Column(db.String(50),  nullable=False)
    payment_method = db.Column(db.String(50),  default='Cash') # ── NEW FIELD ──
    created_at     = db.Column(db.DateTime,    default=datetime.utcnow)
    user_id        = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    def to_dict(self):
        return {
            'id':             self.id,
            'title':          self.title,
            'amount':         self.amount,
            'is_expense':     self.is_expense,
            'date':           self.date.isoformat(),
            'category':       self.category,
            'payment_method': self.payment_method, # ── NEW FIELD ──
        }