from models.database import db

class Goal(db.Model):
    __tablename__ = 'goals'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    
    # ── THE FIX: Put the column back to satisfy PostgreSQL ──
    category = db.Column(db.String(50), nullable=False, default='Legacy') 
    
    budget_amount = db.Column(db.Float, nullable=False)
    start_date = db.Column(db.DateTime, nullable=False)
    end_date = db.Column(db.DateTime, nullable=False)
    alert_threshold = db.Column(db.Float, nullable=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'category': self.category,
            'budget_amount': self.budget_amount,
            'start_date': self.start_date.isoformat(),
            'end_date': self.end_date.isoformat(),
            'alert_threshold': self.alert_threshold,
        }