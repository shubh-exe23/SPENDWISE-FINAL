from .database import db
from datetime import datetime

class Outing(db.Model):
    __tablename__ = 'outings'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    location = db.Column(db.String(255))
    date = db.Column(db.String(50))
    raw_events = db.Column(db.Text, nullable=True) # ── NEW: Stores event history
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    debts = db.relationship('OutingDebt', backref='outing', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'location': self.location,
            'date': self.date,
            'raw_events': self.raw_events, # ── NEW
            'friends': [debt.to_dict() for debt in self.debts]
        }

class OutingDebt(db.Model):
    __tablename__ = 'outing_debts'
    
    id = db.Column(db.Integer, primary_key=True)
    outing_id = db.Column(db.Integer, db.ForeignKey('outings.id'), nullable=False)
    friend_name = db.Column(db.String(100), nullable=False)
    amount = db.Column(db.Float, nullable=False)
    is_owed_to_me = db.Column(db.Boolean, nullable=False) # True = Receive (Red), False = Pay (Green)
    is_settled = db.Column(db.Boolean, default=False)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.friend_name,
            'amount': self.amount,
            'is_owed_to_me': self.is_owed_to_me,
            'is_settled': self.is_settled
        }