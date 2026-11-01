from reset_store import issue_code, consume_code
from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
# ── IMPORT THE HASHING TOOLS ──
from werkzeug.security import generate_password_hash, check_password_hash
from models.user import User, db

auth_bp = Blueprint('auth', __name__)

# ==========================================
#  SECURED EXISTING ROUTES
# ==========================================

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    name = data.get('name', '') 
    
    if User.query.filter_by(email=email).first():
        return jsonify({'success': False, 'message': 'Email already exists'}), 400
        
    # ── 1. HASH THE PASSWORD ON REGISTRATION ──
    hashed_password = generate_password_hash(password)
    
    new_user = User(email=email, password=hashed_password, name=name)
    db.session.add(new_user)
    db.session.commit()
    
    return jsonify({'success': True, 'message': 'User created'}), 201

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    
    user = User.query.filter_by(email=email).first()
    
    # ── 2. SECURELY CHECK THE HASHED PASSWORD ──
    if user and check_password_hash(user.password, password):
        access_token = create_access_token(identity=str(user.id))
        return jsonify({
            'success': True, 
            'token': access_token, 
            'user': user.to_dict()
        }), 200
        
    return jsonify({'success': False, 'message': 'Invalid credentials'}), 401

@auth_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    return jsonify(user.to_dict()), 200

@auth_bp.route('/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    data = request.json
    
    if 'name' in data:
        user.name = data['name']
    if 'currency' in data:
        user.currency = data['currency']
    if 'avatar' in data:                      
        user.profile_pic = data['avatar'] # ── SAVES TO profile_pic ──
        
    db.session.commit()
    return jsonify(user.to_dict()), 200

# ==========================================
#  SECURED OTP / FORGOT PASSWORD ROUTES
# ==========================================

# Codes are shared across serverless instances; no user/database schema changes.

@auth_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
    data = request.json
    email = data.get('email')
    
    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({'success': True, 'message': 'If email exists, OTP sent.'}), 200
        
    try:
        otp = issue_code(email)
    except Exception:
        return jsonify({'success': False, 'message': 'Password reset is temporarily unavailable'}), 503
    
    print(f"\n==============================")
    print(f" PASSWORD RESET OTP FOR {email}: {otp}")
    print(f"==============================\n")
    
    return jsonify({'success': True, 'message': 'OTP sent successfully'}), 200

@auth_bp.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.json
    email = data.get('email')
    otp = data.get('otp')
    new_password = data.get('new_password')
    
    if not isinstance(email, str) or not isinstance(new_password, str) or not new_password:
        return jsonify({'success': False, 'message': 'Invalid reset request'}), 400
    try:
        valid_code = consume_code(email, otp)
    except Exception:
        return jsonify({'success': False, 'message': 'Password reset is temporarily unavailable'}), 503
    if not valid_code:
        return jsonify({'success': False, 'message': 'Invalid or expired OTP'}), 400
        
    user = User.query.filter_by(email=email).first()
    if user:
        # ── 3. HASH THE NEW PASSWORD ──
        user.password = generate_password_hash(new_password) 
        db.session.commit()
        
        return jsonify({'success': True, 'message': 'Password reset successfully'}), 200
        
    return jsonify({'success': False, 'message': 'User not found'}), 404