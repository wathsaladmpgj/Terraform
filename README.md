# AWS Enterprise Network Architecture using Terraform

This project demonstrates how to design and implement a **production-style AWS network architecture** using **Terraform (Infrastructure as Code)**.

The focus is not only on *creating resources*, but on understanding **WHY each component exists**, **HOW traffic flows**, and **HOW everything connects together**.

---

## 🎯 Project Goal (WHY this project exists)

Modern cloud systems must be:
- Secure
- Highly available
- Scalable
- Easy to manage

This project simulates how **real companies design AWS networks** by separating:
- Internet-facing resources
- Private application workloads
- Shared infrastructure services

---

## 🧱 High-Level Architecture

The architecture consists of:

- **Two VPCs**
  - App VPC (application workloads)
  - Shared VPC (common services)
- **Public & Private subnets**
- **Controlled routing using route tables**
- **Secure internet access**
- **Private VPC-to-VPC communication**

---

## 🧠 Network Design Details (VERY IMPORTANT)

### 1️⃣ Why VPC is used

A **VPC (Virtual Private Cloud)** is your private, isolated network in AWS.

WHY include:
- Complete IP address control
- Network isolation from other customers
- Foundation for security and routing

This project uses **two VPCs** to simulate real-world separation of concerns.

---

### 2️⃣ Why two VPCs (App VPC & Shared VPC)

#### App VPC
Purpose:
- Hosts application servers
- Runs backend services
- Contains private workloads

Why separate:
- Limits blast radius
- Application teams don’t access shared infrastructure directly

#### Shared VPC
Purpose:
- Bastion hosts
- Monitoring
- DNS
- Central admin tools

Why separate:
- Shared services should not be mixed with app traffic
- Easier security and access control
- Common enterprise pattern

---

### 3️⃣ Why Public and Private Subnets

#### Public Subnet
Used for:
- NAT
- Load Balancers
- Bastion hosts

Why public:
- Needs direct internet access
- Has a route to Internet Gateway

#### Private Subnet
Used for:
- Application servers
- Databases
- Internal services

Why private:
- No inbound internet access
- Strong security boundary
- Reduces attack surface

👉 **Important rule**:  
A subnet is “public” or “private” **ONLY because of its route table**, not its name.

---

### 4️⃣ Why Route Tables are Critical

Route tables define **how traffic moves**.

Without route tables:
- Subnets cannot communicate
- Internet access fails
- VPC peering does not work

Each subnet has a **specific route table** to control traffic.

---

### 5️⃣ Why Internet Gateway (IGW) is needed

The Internet Gateway:
- Connects a VPC to the public internet
- Allows inbound and outbound internet traffic

Why include:
- Public subnets must talk to the internet
- Load balancers need external access

Only **public subnets** have routes pointing to the IGW.

---

### 6️⃣ Why NAT is needed (VERY IMPORTANT)

Private instances need to:
- Download updates
- Pull Docker images
- Access APIs

But they must NOT:
- Be reachable from the internet

Solution:
- **NAT (Network Address Translation)**

How it works:
