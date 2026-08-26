import uuid
from datetime import datetime, timezone
import pymongo
from bson import ObjectId

class MongoDocumentSnapshot:
    def __init__(self, doc):
        self.exists = doc is not None
        if doc:
            # We treat the string version of _id as the Firestore document id
            self.id = str(doc.pop('_id'))
            self._data = doc
        else:
            self.id = None
            self._data = {}

    def to_dict(self):
        return self._data

class MongoDocumentReference:
    def __init__(self, collection, doc_id):
        self.collection = collection
        self.id = doc_id

    def get(self):
        doc = self.collection.find_one({"_id": self.id})
        return MongoDocumentSnapshot(doc)

    def set(self, data, merge=False):
        data = self._process_data(data)
        if merge:
            self.collection.update_one({"_id": self.id}, {"$set": data}, upsert=True)
        else:
            data['_id'] = self.id
            self.collection.replace_one({"_id": self.id}, data, upsert=True)

    def update(self, data):
        data = self._process_data(data)
        self.collection.update_one({"_id": self.id}, {"$set": data})

    def delete(self):
        self.collection.delete_one({"_id": self.id})

    def _process_data(self, data):
        # We need to process firestore.SERVER_TIMESTAMP here
        from firebase_admin import firestore
        processed = {}
        for k, v in data.items():
            if v == firestore.SERVER_TIMESTAMP:
                processed[k] = datetime.now(timezone.utc)
            else:
                processed[k] = v
        return processed

class MongoQuery:
    def __init__(self, collection, query=None):
        self.collection = collection
        self.query = query or {}

    def where(self, field, op, value):
        new_query = self.query.copy()
        if op == "==":
            new_query[field] = value
        elif op == "in":
            new_query[field] = {"$in": value}
        elif op == ">":
            new_query[field] = {"$gt": value}
        elif op == "<":
            new_query[field] = {"$lt": value}
        elif op == ">=":
            new_query[field] = {"$gte": value}
        elif op == "<=":
            new_query[field] = {"$lte": value}
        else:
            raise NotImplementedError(f"Operator {op} not implemented in Mongo bridge.")
        
        return MongoQuery(self.collection, new_query)

    def stream(self):
        cursor = self.collection.find(self.query)
        for doc in cursor:
            yield MongoDocumentSnapshot(doc)
            
    def get(self):
        # some firestore queries use .get() instead of stream()
        return list(self.stream())

class MongoCollectionReference(MongoQuery):
    def __init__(self, db, name):
        super().__init__(db[name])
        self.db = db
        self.name = name

    def document(self, doc_id=None):
        if doc_id is None:
            # Firestore generates a 20-char random ID, we can use a UUID
            doc_id = str(uuid.uuid4())
        return MongoDocumentReference(self.collection, doc_id)

    def add(self, data):
        doc_id = str(uuid.uuid4())
        data_to_insert = data.copy()
        data_to_insert['_id'] = doc_id
        
        # Process timestamps
        from firebase_admin import firestore
        for k, v in data_to_insert.items():
            if v == firestore.SERVER_TIMESTAMP:
                data_to_insert[k] = datetime.now(timezone.utc)
                
        self.collection.insert_one(data_to_insert)
        
        # Firestore add() returns (update_time, DocumentReference)
        return (datetime.now(timezone.utc), MongoDocumentReference(self.collection, doc_id))

class MongoFirestoreClient:
    def __init__(self, uri):
        self.client = pymongo.MongoClient(uri)
        # Using a default database named "smart_retail_db" since no DB name is in the generic URI
        self.db = self.client.get_database("smart_retail_db")

    def collection(self, name):
        return MongoCollectionReference(self.db, name)
