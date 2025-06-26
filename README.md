## 🛒 MyShop Database (PostgreSQL)

This project contains a normalized PostgreSQL database schema for an **Online Store**. The database supports essential e-commerce functionality including user management, product listing, discount handling, shopping cart and order processing, and payment tracking.

---

### 📁 File Structure

| File Name       | Description                                                                                                                                       |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `schema.sql`    | Contains the full schema: tables, fields, relationships, constraints, and indexes.                                                                |
| `functions.sql` | Includes stored functions for business logic (e.g., stock updates, total cost calculations).                                                      |
| `triggers.sql`  | Contains trigger functions and trigger definitions to ensure data integrity and automate tasks (e.g., setting timestamps, enforcing stock rules). |

---

### 🧩 Features

* **User & Vendor Management**
  Users can register as customers or vendors with role-based differentiation.

* **Shops & Products**
  Vendors can manage shops and product listings, including price and inventory.

* **Discount Handling**
  Products support time-bound percentage-based discounts.

* **Cart & Orders**
  Users can add products to carts, place orders, and track delivery status.

* **Payments**
  Orders are linked with payments, supporting method tracking and timestamps.

* **Data Integrity**
  Enforced through constraints, foreign keys, and PostgreSQL triggers.

---

### 🧪 Example Use Cases

* Add a new product to a vendor’s shop.
* Apply a discount to a product and query the final selling price.
* Automatically update stock when an order is placed.
* Calculate total order value using a function that considers discounts.

---

### 🧠 Skills & Concepts Used

* PostgreSQL SQL and PL/pgSQL
* Relational Database Design (Normalization, Foreign Keys)
* Triggers and Stored Procedures
* Time-based logic and constraints
* E-commerce data modeling

---
