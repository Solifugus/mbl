
# Modern Business Language (MBL)

## Overview

In the realm of business software development, one language has dominated for decades: COBOL, born in 1959. While COBOL has seen updates like object-orientation, it remains a low-level language lacking modern features vital for efficient business data processing and integration.

Modern Business Language (MBL) emerges as a solution, designed to prioritize data safety and adaptability in an ever-evolving business landscape. Drawing on five decades of lessons since COBOL's inception, MBL steps boldly into the world of data science and artificial intelligence on the international business stage.

## Table of Contents

- [Introduction](#introduction)
- [Features & Capabilities](#features-and-capabilities)
  - [Data Safety](#data-safety)
  - [Disaster Recovery](#disaster-recovery)
  - [Auditability](#auditability)
  - [Resilience to Change](#resilience-to-change)
  - [Fast Onboarding of New Developers](#fast-onboarding-of-new-developers)
  - [Unlimited Scalability](#unlimited-scalability)
  - [High Developer Performance](#high-developer-performance)
  - [High Execution Performance](#high-execution-performance)
  - [Enterprise Interfaces](#enterprise-interfaces)
- [Design Concepts](#design-concepts)
  - [Program Structure](#program-structure)
  - [Data Types](#data-types)

# Introduction

MBL revolutionizes business computing by providing comprehensive capabilities while minimizing complexity. Unlike traditional programming languages, MBL operates through conditions mapped to assignments. Programs in MBL don't start or stop; they continuously respond to conditions, making decisions based on "what-if" scenarios and preferences.

Whether running on a single server or across a network of interconnected instances, MBL retains its uniformity. It forms a peer-to-peer mesh network, acting as a single cohesive unit.

A MBL program consists of services that execute on beats (scheduled times) or off beats (on-demand). This heartbeat coordination ensures seamless mesh network operation.

# Features and Capabilities

Here's a concise look at how MBL addresses crucial business language requirements:

## Data Safety

MBL offers three layers of data safety:
1. **Constraints and Consequences:** Watched conditions ensure data integrity. Broken constraints trigger consequences, preventing defects and allowing self-healing processes.
2. **Objective Execution:** Processes trigger based on specific conditions, ensuring actions occur precisely when needed.
3. **Agency:** MBL can make decisions based on established constraints and interests, employing AI for optimal choices and resolving ambiguities.

## Disaster Recovery

MBL simplifies disaster recovery by seamlessly integrating servers across locations into a singular mesh. Data redundancy is maintained across locations, eliminating downtime or the risk of failed recovery.

## Auditability

MBL tackles audit challenges through data safety, temporal data storage, and tree graph data structure. Constraints and consequences, combined with detailed temporal data storage, ensure flawless data reconstruction. The tree graph structure simplifies data retrieval, reducing audit preparation time.

## Resilience to Change

MBL excels in adapting to evolving business processes. Data structure flexibility and objective execution mean processes execute based on conditions, irrespective of data changes. There's no need for extensive procedural modifications, making MBL a "living" language.

## Fast Onboarding of New Developers

MBL simplifies developer onboarding with its focus on high readability and intent-driven programming. Developers need not worry about database intricacies; they specify what they want based on data characteristics, reducing the learning curve.

## Unlimited Scalability

MBL's mesh network execution allows effortless scalability. Adding or removing capacity is a matter of configuration. MBL automatically distributes work and maintains redundancy.

## High Developer Performance

MBL enhances developer performance through intuitive controls, agency, and contemplation. Developers specify what they want to achieve, and MBL provides insights into the outcomes, streamlining decision-making and implementation.

## High Execution Performance

MBL prioritizes safety and developer performance, but its distributed mesh model ensures high execution performance for most business data processing scenarios.

## Enterprise Interfaces

MBL introduces a universal interface notation for GUI, web, REST, or conversational interfaces, promoting consistency and automation.

# Design Concepts

MBL draws inspiration from SQL, ADA, Python, and JavaScript. It aims to automate data transitions, increase data quality through constraints, and leverage flexible data structures for efficient programming.

## Program Structure

MBL organizes programs into objects, similar to JavaScript objects but with cleaner namespaces. A global object contains standard language elements, ensuring minimal pollution.

```mbl
service ship_order( order[paid >= order.balance and product.instock = true and ship_date is Nothing]  ):
  order.shippable = true
```

## Data Types

MBL supports essential data types:
- **Text:** Strings of bytes with ASCII characters and interpolated elements.
- **Number:** Real numbers with comma-separated thousands for clarity.
- **Boolean:** Yes or No for enhanced readability.
- **Time:** Representing durations or specific times in UTC.
- **Money:** Numbers with defined currency rules, defaulting to USDollar.
