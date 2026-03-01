"""
Firestore Service for RepSync Bot
"""
import os
import firebase_admin
from firebase_admin import credentials, firestore

def init_firestore(credentials_path: str):
    """Initialize Firebase Admin SDK and return Firestore client"""
    
    # Check if credentials file exists
    if not os.path.exists(credentials_path):
        # Try to use default credentials
        try:
            firebase_admin.initialize_app()
            return firestore.client()
        except Exception as e:
            print(f"Error initializing Firebase with default credentials: {e}")
            print("Please provide serviceAccountKey.json")
            return None
    
    # Initialize with credentials file
    cred = credentials.Certificate(credentials_path)
    firebase_admin.initialize_app(cred)
    
    return firestore.client()

async def link_user_account(db, telegram_id: str, user_id: str, telegram_data: dict):
    """Link Telegram account to RepSync user"""
    
    try:
        # Check if Telegram ID is already linked
        users_ref = db.collection('users')
        existing = users_ref.where('telegramId', '==', telegram_id).limit(1).stream()
        
        if list(existing):
            return {
                'success': False,
                'error': 'already_linked',
                'message': 'Telegram account already linked'
            }
        
        # Find RepSync user
        user_doc = users_ref.document(user_id).get()
        
        if not user_doc.exists:
            return {
                'success': False,
                'error': 'user_not_found',
                'message': 'User not found'
            }
        
        # Update user document
        update_data = {
            'telegramId': telegram_id,
            'telegramUsername': telegram_data.get('username'),
            'telegramFirstName': telegram_data.get('first_name'),
            'telegramLastName': telegram_data.get('last_name'),
            'telegramLinkedAt': firestore.SERVER_TIMESTAMP,
        }
        
        # Save Telegram photo ID if available
        if telegram_data.get('photo'):
            update_data['telegramPhotoId'] = telegram_data['photo']
        
        await users_ref.document(user_id).update(update_data)
        
        return {
            'success': True,
            'message': 'Account linked successfully'
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': 'internal_error',
            'message': str(e)
        }

async def unlink_user_account(db, telegram_id: str):
    """Unlink Telegram account from RepSync"""
    
    try:
        users_ref = db.collection('users')
        existing = users_ref.where('telegramId', '==', telegram_id).limit(1).stream()
        
        users_list = list(existing)
        if not users_list:
            return {
                'success': False,
                'error': 'not_linked',
                'message': 'Telegram account not linked'
            }
        
        user_doc = users_list[0]
        await users_ref.document(user_doc.id).update({
            'telegramId': firestore.DELETE_FIELD,
            'telegramUsername': firestore.DELETE_FIELD,
            'telegramFirstName': firestore.DELETE_FIELD,
            'telegramLastName': firestore.DELETE_FIELD,
            'telegramLinkedAt': firestore.DELETE_FIELD,
            'telegramPhotoId': firestore.DELETE_FIELD,
        })
        
        return {
            'success': True,
            'message': 'Account unlinked successfully'
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': 'internal_error',
            'message': str(e)
        }

async def get_user_status(db, telegram_id: str):
    """Get user account status"""
    
    try:
        users_ref = db.collection('users')
        existing = users_ref.where('telegramId', '==', telegram_id).limit(1).stream()
        
        users_list = list(existing)
        if not users_list:
            return {
                'linked': False,
                'message': 'Not linked'
            }
        
        user_doc = users_list[0]
        user_data = user_doc.to_dict()
        
        return {
            'linked': True,
            'user_id': user_doc.id,
            'display_name': user_data.get('displayName', 'N/A'),
            'email': user_data.get('email', 'N/A'),
            'message': 'Account is linked'
        }
        
    except Exception as e:
        return {
            'linked': False,
            'error': str(e)
        }
