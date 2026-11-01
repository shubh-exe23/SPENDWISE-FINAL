from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models.database import db
from models.category import Category
from models.transaction import Transaction # ── ADDED TO UPDATE TRANSACTIONS ──

categories_bp = Blueprint('categories', __name__, url_prefix='/categories')

@categories_bp.route('', methods=['GET'])
@jwt_required()
def get_categories():
    user_id = get_jwt_identity()
    categories = Category.query.filter(
        (Category.user_id == user_id) | (Category.is_default == True)
    ).all()
    return jsonify([c.to_dict() for c in categories]), 200

@categories_bp.route('', methods=['POST'])
@jwt_required()
def add_category():
    user_id = get_jwt_identity()
    data = request.json
    
    existing = Category.query.filter_by(name=data['name'], user_id=user_id).first()
    if existing:
        return jsonify({"error": "Category already exists"}), 400

    new_category = Category(
        name=data['name'],
        icon=data.get('icon', 'category'),   
        color=data.get('color', '#3EB489'),  
        user_id=user_id,
        is_default=False
    )
    
    db.session.add(new_category)
    db.session.commit()
    
    return jsonify(new_category.to_dict()), 201

@categories_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_category(id):
    user_id = get_jwt_identity()
    category = Category.query.filter_by(id=id, user_id=user_id, is_default=False).first()
    
    if not category:
        return jsonify({"error": "Category not found"}), 404
        
    db.session.delete(category)
    db.session.commit()
    return jsonify({"message": "Category deleted successfully"}), 200

@categories_bp.route('/by-name/<string:name>', methods=['DELETE'])
@jwt_required()
def delete_category_by_name(name):
    user_id = get_jwt_identity()
    
    # 1. Delete from categories table if it exists
    category = Category.query.filter_by(name=name, user_id=user_id, is_default=False).first()
    if category:
        db.session.delete(category)
        
    # 2. MAGIC FIX: Move old transactions to 'Extra' so the category stays dead!
    Transaction.query.filter_by(category=name, user_id=user_id).update({'category': 'Extra'})
    
    db.session.commit()
    # Return 200 even if it wasn't in the category table to fix the 404!
    return jsonify({"message": "Category deleted successfully"}), 200

@categories_bp.route('/by-name/<string:old_name>', methods=['PUT'])
@jwt_required()
def update_category_by_name(old_name):
    user_id = get_jwt_identity()
    data = request.json
    new_name = data['new_name']
    
    # 1. Update in categories table if it exists
    category = Category.query.filter_by(name=old_name, user_id=user_id, is_default=False).first()
    if category:
        category.name = new_name
        
    # 2. MAGIC FIX: Update ALL past transactions so the old name doesn't resurrect!
    Transaction.query.filter_by(category=old_name, user_id=user_id).update({'category': new_name})
    
    db.session.commit()
    # Return 200 even if it wasn't in the category table to fix the 404!
    return jsonify({"message": "Category updated successfully"}), 200