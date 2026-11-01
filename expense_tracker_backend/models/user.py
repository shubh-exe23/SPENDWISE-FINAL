from models.database import db

class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    name = db.Column(db.String(100), default='User')
    
    currency = db.Column(db.String(10), default='₹ INR')
    language = db.Column(db.String(50), default='English')
    
    # ── THIS MUST SAY profile_pic ──
    profile_pic = db.Column(db.Text, nullable=True) 
    phone = db.Column(db.String(20), nullable=True)
    
    created_at = db.Column(db.DateTime, server_default=db.func.now())

    def to_dict(self):
        return {
            'id': self.id,
            'email': self.email,
            'name': self.name,
            'phone': self.phone, 
            'currency': self.currency,
            'language': self.language,
            # ── FLUTTER READS THIS AS 'avatar' ──
            'avatar': self.profile_pic, 
            'created_at': self.created_at.isoformat() if self.created_at else None
        }