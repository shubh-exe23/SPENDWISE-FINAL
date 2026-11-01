from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models.database import db
from models.outing import Outing, OutingDebt

outings_bp = Blueprint('outings', __name__, url_prefix='/outings')

# ── 1. FETCH ALL OUTINGS ──
@outings_bp.route('', methods=['GET'])
@jwt_required()
def get_outings():
    user_id = get_jwt_identity()
    # Order by newest first
    outings = Outing.query.filter_by(user_id=user_id).order_by(Outing.created_at.desc()).all()
    return jsonify([o.to_dict() for o in outings]), 200

# ── 2. SAVE A NEW OUTING & ITS DEBTS ──
@outings_bp.route('', methods=['POST'])
@jwt_required()
def add_outing():
    user_id = get_jwt_identity()
    data = request.json
    
    new_outing = Outing(
        title=data['title'],
        location=data.get('location', ''),
        date=data.get('date', ''),
        raw_events=data.get('raw_events', '[]'), # ── NEW
        user_id=user_id
    )
    db.session.add(new_outing)
    db.session.flush() 
    
    for friend in data.get('friends', []):
        new_debt = OutingDebt(
            outing_id=new_outing.id,
            friend_name=friend['name'],
            amount=friend['amount'],
            is_owed_to_me=friend['is_owed_to_me'],
            is_settled=friend.get('is_settled', False)
        )
        db.session.add(new_debt)
        
    db.session.commit()
    return jsonify(new_outing.to_dict()), 201

# ── 4. UPDATE ENTIRE OUTING (EDIT) ──
@outings_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_outing(id):
    user_id = get_jwt_identity()
    data = request.json
    
    outing = Outing.query.filter_by(id=id, user_id=user_id).first()
    if not outing:
        return jsonify({'error': 'Outing not found'}), 404
        
    outing.title = data['title']
    outing.location = data.get('location', '')
    outing.raw_events = data.get('raw_events', '[]')
    
    # Wipe old debts and replace with the recalculated ones
    OutingDebt.query.filter_by(outing_id=outing.id).delete()
    
    for friend in data.get('friends', []):
        new_debt = OutingDebt(
            outing_id=outing.id,
            friend_name=friend['name'],
            amount=friend['amount'],
            is_owed_to_me=friend['is_owed_to_me'],
            is_settled=friend.get('is_settled', False)
        )
        db.session.add(new_debt)
        
    db.session.commit()
    return jsonify(outing.to_dict()), 200

# ── 5. DELETE OUTING ──
@outings_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_outing(id):
    user_id = get_jwt_identity()
    outing = Outing.query.filter_by(id=id, user_id=user_id).first()
    
    if not outing:
        return jsonify({'error': 'Outing not found'}), 404
        
    db.session.delete(outing)
    db.session.commit()
    return jsonify({'message': 'Deleted successfully'}), 200

# ── 3. UPDATE A DEBT (PARTIAL OR COMPLETE SETTLEMENT) ──
@outings_bp.route('/debt/<int:debt_id>', methods=['PUT'])
@jwt_required()
def update_debt(debt_id):
    user_id = get_jwt_identity()
    data = request.json
    
    # 1. Fetch the exact debt directly
    debt = OutingDebt.query.get(debt_id)
    if not debt:
        return jsonify({'error': 'Debt not found'}), 404
        
    # 2. Safely verify ownership (Casting both to strings fixes strict matching bugs!)
    if str(debt.outing.user_id) != str(user_id):
        return jsonify({'error': 'Unauthorized access to this debt'}), 403
        
    # 3. Apply the new partial amount and settlement status
    debt.amount = data.get('amount', debt.amount)
    debt.is_settled = data.get('is_settled', debt.is_settled)
    
    db.session.commit()
    return jsonify(debt.to_dict()), 200