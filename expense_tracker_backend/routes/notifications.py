from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models.database import db
from models.notification import Notification

notifications_bp = Blueprint('notifications', __name__, url_prefix='/notifications')

@notifications_bp.route('', methods=['GET'])
@jwt_required()
def get_notifications():
    user_id = get_jwt_identity()
    # Fetch in chronological order
    notifications = Notification.query.filter_by(user_id=user_id).order_by(Notification.created_at.asc()).all()
    return jsonify([n.to_dict() for n in notifications]), 200

@notifications_bp.route('', methods=['POST'])
@jwt_required()
def add_notification():
    user_id = get_jwt_identity()
    data = request.json
    n = Notification(
        title=data['title'],
        message=data['message'],
        type=data['type'],
        is_read=False,
        user_id=user_id
    )
    db.session.add(n)
    db.session.commit()
    return jsonify(n.to_dict()), 201

@notifications_bp.route('/mark-all-read', methods=['PUT'])
@jwt_required()
def mark_all_read():
    user_id = get_jwt_identity()
    # Update all unread notifications for this user in one go
    Notification.query.filter_by(user_id=user_id, is_read=False).update({'is_read': True})
    db.session.commit()
    return jsonify({'message': 'All marked as read'}), 200