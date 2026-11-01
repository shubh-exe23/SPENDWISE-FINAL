from .database import db
from datetime import datetime

class Category(db.Model):
    __tablename__ = 'categories'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    icon = db.Column(db.String(255))
    color = db.Column(db.String(50))
    # ── CHANGE THIS LINE ──
    user_id = db.Column(db.Integer, nullable=False) 
    is_default = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'icon': self.icon,
            'color': self.color,
            'user_id': self.user_id,
            'is_default': self.is_default,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }