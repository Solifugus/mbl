
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

Example:
```mbl
program importNewFiles( vendor_folder ):
  foreach( file, vendor_folder ):
    if( imported_files[ file.name = Nothing ] ):
      import( file )
      imported_files << file.name
```

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

MBL excels in adapting to evolving business processes. Data structure flexibility and objective execution mean processes execute based on conditions, irrespective of data changes. There's no need for extensive procedural modifications, making MBL a language that never sleeps.

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

MBL simplifies data handling by primarily focusing on three fundamental data types:

- **Nothing:** This represents the absence of data or an undefined value. It's useful when a variable or field doesn't have a meaningful value to assign.

- **Unknown:** Similar to "Nothing," "Unknown" indicates that the data's value is currently unknown or uncertain. It can be particularly valuable when working with incomplete or ambiguous information.

- **Text:** The core data type in MBL, "Text" is a versatile type that can take on different forms when it adheres to specific constraints. MBL recognizes built-in forms within text, including:

  - **Number:** When text follows specific formatting rules for numbers, MBL interprets it as a numerical value. For example, `"123.45"` would be recognized as the number 123.45.

  - **Time:** Text that conforms to predefined date and time formats can be treated as time data. For instance, `T"2023-06-15 15:30:00"` is recognized as a specific date and time.

  - **Money:** When text adheres to currency formatting rules, MBL interprets it as a monetary value. For example, `"$1,234.56"` is recognized as 1,234.56 in the default currency (USDollar).

  - **Record:** Text can represent structured data when it conforms to the syntax of a record. Records allow you to group related data fields together, enhancing data organization and manipulation.

These three fundamental data types, along with their specialized forms within text, provide the foundation for managing data in MBL. By simplifying the data model to these core types, MBL promotes clarity and flexibility in data handling.

## Variables and Assignments

A variable is a label that holds a value.  The value may be of any data type consistent with any constraints applied to the variable.  In MBL, a variable is declared by assigning a value to it.  By default, all variables hold the value Nothing.

- To assign nothing (effectively undeclaring): `x = Nothing`
- To assign a strictly literal string: `x = "my literal string"`
- To assign a string with interpolated values: `x = f"The charge for [num] apples at [price] each is [num*price]."`
- To assign a number: `x = 123.45`
- To assign a large number: `x = 1_200_400.25` (underscores separate thousands)
- To assign a US dollar value: `x = $31_500.00`
- To assign a Korean Won value: `x = $1_500 Won`
- To assign a time: `x = t"15:30:00"`
- To assign a datetime: `x = t"2023-08-15 15:30:00"`
- To assign time as a duration: `x = 15 minutes 23 seconds`
- To assign metric measures: `x = 1.5 kilograms`

# Language Implementation Design

This language is implemented in an unusual way.
Source code is processes through a lexical analyzer into tokens.
Each token is associated with a function that returns a value.
By default, an alphanumeric token returns the last value it was assigned as modified by any token adjacent to the right.
In other words, a token may offer the token to the right the opportunity to modify it before returning the final value.
The returned value also includes the index of the next token to execute.

Philosophically, in MBL, there a variable is merely a special (default) class of function.

## Lexer

The Lexer converts source code text into program tokens.
So it converts UTF8 text to the token types:
- Text.  This is any UTF8 text within quotes, such as "A line of text".
- Numeric.  This is a string of numeric digits with a few exceptions: one optional period (".") or any number of underscores are allowed between numeric digits and a single negative symbol ("-") is allowed at the start or end.
- Alphanumeric.  one or more adjacent alphanumeric characters where the first is alphabetic.
- New Line.  One or more adjacent new line characters.  This token should carry the count of adjacent new line characters.
- Tab.  One or more adjacent tab characters.  This token should carry the count of adjacent tabs.
- Symbol.  Any other visible character, as its own individual token.

## Placer

The Placer derives the structure of the tokens and places them in the appropriate storage locations.
This includes the creation of links necessary to integrate with other code already in storage.

## Runner

The Runner executes the functions at a specified place in storage.
This is done by executing the first token and then its returned next token until all tokens have been executed.
To execute a token, a value is passed to it.  The Runner will pass the Nothing value.
A token returns a value and the index of the next (not yet run token).  
Each token's associated function may or may not call the token to the right passing its value and accepting a modified value plus the index to the next unexecuted token.

# Bootsrap tokens

To make this language work, it must begin with a set of hard-coded functions.
The runner should have already applied code definitions to by means of the ":" operator.
The "=" assignment operator should call the token on the right to gather a value and return instructions to the token on the left to assign the value to itself.
Similarly, the are boostrap tokens for basic arithmetic and logical operations.
The Text and Numeric tokens should have their own specialized functions.
Every function may optionally take parameters, suffixed within braces, so as to affect what they do.
All of this will be features added incrementally.

However, the ":" operator is a way of assigning programming code to a token.  
This allows for the definition of custom tokens.

