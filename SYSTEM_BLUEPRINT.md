# StockPro Multi-User Store Management System Blueprint

## 🎯 Current System Status (Production Ready - Phase 1 Complete)

### ✅ Completed Core Features

- **Modern Authentication System**: Professional gradient UI (Color(0xFF1E88E5) → Color(0xFF1976D2) → Color(0xFF0D47A1))
- **Local Session Management**: SharedPreferences + SQLite with Provider pattern
- **Route-Based Navigation**: /login, /register, /onboarding, /welcome-back, /dashboard
- **Debug System**: Comprehensive user data inspection with debugListAllUsers()
- **User Modes**: Guest, Basic, Pro, ProPlus with feature restrictions
- **Demo Data System**: Local storage for testing and development

### 🏗️ Architecture Foundation

```
lib/
├── services/
│   └── auth_service.dart      # Core authentication & session management
├── screens/
│   └── auth/
│       ├── login_screen.dart  # Modern gradient authentication UI
│       └── register_screen.dart
├── models/
│   ├── user_mode.dart         # User permission levels
│   └── auth_result.dart       # Authentication response handling
└── main.dart
```

### 🔑 Key Technical Components

#### AuthService Core Methods

```dart
// Professional Authentication
Future<AuthResult> login({required String email, required String password, bool rememberMe})
Future<AuthResult> register({required String name, email, password, storeName})
Future<AuthResult> logout()

// Session Management
Future<UserSession?> restoreSession()
Future<UserSession> startGuestSession({required String userName, storeName})
Future<UserSession> loginUser({required String userId, userName, userEmail, storeName, mode})

// Debug & Development
Future<void> debugListAllUsers() // Comprehensive user data inspection
```

#### User Permission System

- **Guest Mode**: Basic inventory only
- **Basic Mode**: + Cloud sync, supplier management, data export
- **Pro Mode**: + Multi-user, advanced reports, unlimited products
- **ProPlus Mode**: + AI analytics, API integrations

## 🚀 Next Phase: Multi-User Firebase Architecture

### Target Multi-User System Requirements

```
SCENARIO: 3 partners managing 1 store from separate phones
- Partner A, B, C each have individual accounts
- All access same store inventory in real-time
- Store owner can invite partners via email/code
- Real-time synchronization across all devices
- Admin can control access permissions per partner
```

### 🔥 Firebase Integration Plan

#### 1. Firestore Database Structure

### 🔥 Core Collections

#### **users** - User Management

```firestore
users/{userId}
├── email: string
├── name: string
├── phone: string
├── subscriptionMode: "basic" | "pro" | "premium"
├── createdAt: timestamp
├── lastLogin: timestamp
├── isActive: boolean
└── settings: object
```

#### **stores** - Store Management

```firestore
stores/{storeId}
├── name: string
├── ownerId: string (reference to users collection)
├── address: string
├── city: string
├── phone: string
├── email: string
├── taxNumber: string
├── createdAt: timestamp
├── updatedAt: timestamp
├── isActive: boolean
└── settings: {
    currency: string,
    taxRate: number,
    autoBackup: boolean,
    notifications: object
}
```

### 🏪 Store-Specific Sub-Collections

#### **stores/{storeId}/products** - Product Inventory (Real-time)

```firestore
stores/{storeId}/products/{productId}
├── barcode: string (unique within store)
├── name: string
├── description: string
├── salePrice: number
├── purchasePrice: number
├── stock: number
├── minStock: number
├── taxRate: number
├── category: string
├── createdAt: timestamp
├── updatedAt: timestamp
├── lastModifiedBy: string (userId)
└── isActive: boolean
```

#### **stores/{storeId}/sales** - Sales Transactions (Real-time)

```firestore
stores/{storeId}/sales/{saleId}
├── totalAmount: number
├── discount: number
├── finalAmount: number
├── paymentMethod: "cash" | "card" | "transfer" | "check"
├── userId: string (who made the sale)
├── createdAt: timestamp
└── items: array[
    {
      productId: string,
      productName: string,
      productBarcode: string,
      quantity: number,
      unitPrice: number,
      totalPrice: number
    }
]
```

#### **stores/{storeId}/suppliers** - Supplier Management

```firestore
stores/{storeId}/suppliers/{supplierId}
├── name: string
├── phone: string
├── email: string
├── address: string
├── debt: number
├── totalPurchases: number
├── monthlyPurchases: number
├── yearlyPurchases: number
├── notes: string
├── createdAt: timestamp
├── updatedAt: timestamp
└── isActive: boolean
```

#### **stores/{storeId}/supplier_transactions** - Supplier Payment History

```firestore
stores/{storeId}/supplier_transactions/{transactionId}
├── supplierId: string (reference to suppliers)
├── type: "payment" | "purchase" | "adjustment"
├── amount: number
├── description: string
├── previousDebt: number
├── newDebt: number
├── userId: string (who made the transaction)
├── createdAt: timestamp
└── receiptNumber: string (optional)
```

#### **stores/{storeId}/inventory_changes** - Real-time Stock Changes

```firestore
stores/{storeId}/inventory_changes/{changeId}
├── productId: string (reference to products)
├── type: "sale" | "purchase" | "adjustment" | "return"
├── quantity: number (positive or negative)
├── previousStock: number
├── newStock: number
├── reason: string
├── userId: string (who made the change)
├── saleId: string (if related to sale)
├── timestamp: timestamp
└── deviceInfo: string (for audit trail)
```

#### **stores/{storeId}/members** - Store Team & Invitation Management

```firestore
stores/{storeId}/members/{userId}
├── userId: string (reference to users collection)
├── email: string (for invited users not yet registered)
├── role: "owner" | "manager" | "staff" | "partner"
├── permissions: array["read", "write", "delete", "admin"]
├── status: "owner" | "accepted" | "invited" | "pending" | "rejected"
├── joinedAt: timestamp (when accepted invitation)
├── invitedAt: timestamp (when invitation was sent)
├── invitedBy: string (userId of who sent invitation, null for owner)
├── respondedAt: timestamp (when user responded to invitation)
├── lastActivity: timestamp
└── isActive: boolean (for deactivating without deletion)
```

### 🎯 Store Member Management Flow

#### **Owner Registration Process:**

```
1. User registers → creates store
2. Store created with ownerId
3. Auto-add to store_members:
   - role: "owner"
   - status: "owner"
   - invitedBy: null
   - isActive: true
```

#### **Employee Invitation Process:**

```
1. Owner/Manager clicks "Add Employee"
2. Enters email + selects role
3. Add to store_members:
   - email: "employee@email.com"
   - role: "staff"
   - status: "invited"
   - invitedBy: currentUserId
   - invitedAt: now()

4. Employee registers with that email
5. Check store_members for invitations
6. Show "Join Store" options
7. User accepts → status: "accepted"
8. User rejects → status: "rejected"
```

#### **Member Management Actions:**

```
✅ View all members (invited, accepted, rejected)
✅ Deactivate member (isActive: false)
✅ Delete member (remove from collection)
✅ Change role/permissions
✅ Re-invite rejected users
✅ Cancel pending invitations
```

### 🛡️ Admin Collections

#### **admin_controls** - System Administration

```firestore
admin_controls/system_settings
├── banned_stores: array[storeId]
├── banned_users: array[userId]
├── pending_approvals: array[storeId]
├── payment_status: object
├── maintenance_mode: boolean
└── system_announcements: array
```

### 📊 Analytics Collections (Future)

#### **stores/{storeId}/daily_reports** - Daily Analytics

```firestore
stores/{storeId}/daily_reports/{date}
├── date: string (YYYY-MM-DD)
├── totalSales: number
├── totalTransactions: number
├── topProducts: array
├── lowStockAlerts: array
├── generatedAt: timestamp
└── generatedBy: string (userId or "system")
```

### 📋 SQLite to Firestore Migration Mapping

| SQLite Table          | Firestore Collection                     | Migration Strategy                                 |
| --------------------- | ---------------------------------------- | -------------------------------------------------- |
| `products`            | `stores/{storeId}/products`              | ✅ Direct mapping with storeId prefix              |
| `sales`               | `stores/{storeId}/sales`                 | ✅ Move items array, add userId, remove supplierId |
| `sale_items`          | Embedded in `sales.items[]`              | ✅ Convert to array field                          |
| `suppliers`           | `stores/{storeId}/suppliers`             | ✅ Direct mapping with storeId prefix              |
| `payment_history`     | `stores/{storeId}/supplier_transactions` | ✅ Rename + add metadata                           |
| `transaction_history` | `stores/{storeId}/supplier_transactions` | ✅ Merge with payment_history                      |
| User Settings         | `users/{userId}`                         | ✅ Add phone, subscriptionMode fields              |
| Store Settings        | `stores/{storeId}`                       | ✅ Add city, location fields                       |
| N/A                   | `stores/{storeId}/members`               | ✅ New unified invitation system                   |

### 🔄 Hybrid Storage Strategy

#### **Local Storage (SQLite) - For Performance**

```
🏠 LOCAL CACHE (Fast Access)
├── User preferences & settings
├── Recent transactions (last 30 days)
├── Frequently accessed products
├── Offline operation queue
└── Session data
```

#### **Cloud Storage (Firestore) - For Sync**

```
☁️ FIRESTORE (Real-time Sync)
├── Master product database
├── All sales transactions
├── Supplier management
├── Multi-user coordination
└── Backup & analytics
```

### 🚀 Implementation Strategy

#### **Phase 1: Foundation Setup**

1. ✅ Firebase Authentication (Complete)
2. ✅ Firestore Security Rules (Complete)
3. 🔄 User & Store Collections
4. 🔄 Basic CRUD operations

#### **Phase 2: Core Collections**

1. 🔄 Products real-time sync
2. 🔄 Sales transaction sync
3. 🔄 Inventory change tracking
4. 🔄 Multi-user permissions

#### **Phase 3: Advanced Features**

1. 🔄 Supplier management sync
2. 🔄 Real-time notifications
3. 🔄 Offline operation queue
4. 🔄 Analytics & reporting

#### **Phase 4: Multi-User Features**

1. 🔄 Store invitations
2. 🔄 Role-based permissions
3. 🔄 Real-time collaboration
4. 🔄 Admin control panel

### 🔧 Service Layer Architecture

#### **Firebase Services Structure**

```
lib/services/
├── firebase_auth_service.dart      ✅ (Complete)
├── firestore_service.dart          🔄 (To be created)
├── real_time_sync_service.dart     🔄 (To be created)
├── offline_queue_service.dart      🔄 (To be created)
└── multi_user_service.dart         🔄 (To be created)
```

#### **Model Classes Structure**

```
lib/models/
├── user_model.dart                 🔄 (Update for Firestore)
├── store_model.dart                🔄 (Update for Firestore)
├── product_model.dart              🔄 (Update for Firestore)
├── sale_model.dart                 🔄 (Update for Firestore)
├── supplier_model.dart             🔄 (Update for Firestore)
└── inventory_change_model.dart     🔄 (New for real-time)
```

### 🛡️ Admin Control System

#### **Admin Capabilities**

```
SUPER ADMIN FEATURES:
✅ View all stores and their real-time data
✅ Ban/unban stores instantly (blocks all store access)
✅ Ban/unban individual users (blocks user access)
✅ Approve/reject new store registrations
✅ Monitor system payment status & billing
✅ Access any store's inventory, sales, supplier data
✅ Generate system-wide reports and analytics
✅ Control Firebase security rules remotely
✅ System maintenance mode toggle
✅ Real-time user activity monitoring
```

#### **Admin Security Implementation**

```firestore
admin_controls/system_settings
├── super_admins: ["admin1@email.com", "admin2@email.com"]
├── banned_stores: [storeId1, storeId2]
├── banned_users: [userId1, userId2]
├── pending_store_approvals: [
    {
      storeId: string,
      ownerEmail: string,
      requestedAt: timestamp,
      status: "pending"
    }
]
├── system_settings: {
    maintenance_mode: boolean,
    registration_enabled: boolean,
    max_stores_per_user: number,
    payment_required: boolean
}
└── audit_log: [
    {
      adminId: string,
      action: string,
      targetId: string,
      timestamp: timestamp,
      details: object
    }
]
```

### ⚡ Real-Time Synchronization Features

#### **Live Data Streams**

```dart
// Real-time product inventory updates
FirebaseFirestore.instance
  .collection('stores/$storeId/products')
  .snapshots()
  .listen((snapshot) {
    for (var change in snapshot.docChanges) {
      switch (change.type) {
        case DocumentChangeType.added:
          // New product added by another user
          _handleNewProduct(change.doc);
          break;
        case DocumentChangeType.modified:
          // Product updated (stock, price, etc.)
          _handleProductUpdate(change.doc);
          break;
        case DocumentChangeType.removed:
          // Product deleted
          _handleProductDeletion(change.doc);
          break;
      }
    }
  });
```

#### **Multi-User Conflict Resolution**

- **Last-Write-Wins**: Most recent change overwrites
- **Audit Trail**: Track who changed what and when
- **Real-time Notifications**: Alert users of conflicts
- **Automatic Refresh**: UI updates instantly across devices

#### **Offline-Online Sync Strategy**

```
ONLINE MODE:
├── Direct Firestore operations
├── Real-time listeners active
├── Immediate multi-user sync
└── Live conflict detection

OFFLINE MODE:
├── Queue operations in SQLite
├── Continue working with local data
├── Show "offline" indicator
└── Auto-sync when connection restored

RECONNECTION:
├── Upload queued operations
├── Download missed changes
├── Resolve conflicts
└── Restore real-time listeners
```

### 🔧 Implementation Strategy

#### Phase 2A: Firebase Setup

1. Create Firebase project with Firestore
2. Add Firebase dependencies to pubspec.yaml
3. Configure Firebase for Android/iOS
4. Implement Firebase Authentication alongside local auth

#### Phase 2B: Multi-User Core

1. Create store invitation system
2. Implement real-time Firestore listeners
3. Build partner management UI
4. Add role-based permissions

#### Phase 2C: Admin Dashboard

1. Create admin authentication flow
2. Build comprehensive admin panel
3. Implement ban/approval systems
4. Add system monitoring tools

### 💡 Development Notes

#### Current Debug System

- `debugListAllUsers()` shows all current local data
- Session inspection available in splash screen
- Demo users stored in SharedPreferences
- Password hashing with demo salt

#### Migration Strategy

- Keep local SQLite as offline cache
- Firestore as primary data source
- Gradual migration: Auth → Products → Sales → Analytics

#### Security Considerations

- Firebase Security Rules for multi-tenant data
- Admin-only collections with strict rules
- User invitation verification system
- Encrypted sensitive data

## 🎨 UI/UX Standards Established

- **Color Scheme**: Blue gradient theme (1E88E5 → 1976D2 → 0D47A1)
- **Animation**: flutter_animate for smooth transitions
- **Typography**: Professional, readable fonts
- **Layout**: Mobile-first responsive design
- **Feedback**: Loading states, success/error messages

## 📋 Ready for Next Commands

The system is now at a stable checkpoint. All authentication flows work perfectly with modern UI. Local storage is robust with comprehensive debugging.

**Ready to receive next instructions for:**

1. Firebase integration and setup
2. Multi-user store sharing implementation
3. Admin control system development
4. Real-time synchronization features
5. Any other specific requirements

---

_Blueprint created: August 31, 2025_
_Status: Production Foundation Complete - Ready for Multi-User Firebase Phase_
