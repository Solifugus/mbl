# mbl
Modern Business Language

# Overviev

Although for decades now, computer software has played a vital role in every business, the last programming language developed specifically for general purpose business needs was COBOL, first created in 1959.  Since then, COBOL has experienced modernization in terms of generic trends, such as the addition of object-orientation, but nevertheless remains a low-level language lacking in a variety of higher level features and capabilities desired for efficient business data processing, data integrations, and business applications.

On a broad level, the following features and capabilities are important:

* Data Safety
* Disaster Recovery
* Auditability
* Resilience to Changes
* Fast Onboarding of New Developers
* Unlimited Scalability
* High Developer Performance
* High Execution Performance
* Enterprise Interfaces

In short, MBL aims to solve all of the above with a high level language operating across a distributed mesh network with transparent tree graph data.  That is, software written in MBL does not run on a single server.  Rather, the mesh acts transparently as if it is a single server and software runs across the whole network, simultaneously.  How MBL solves each of the features and capabilities listed above is detailed in the sub-sectins below.

## Data Safety

MBL provides three methods of ensuring data safety: (1) constraints and consequences, (2) objective execution, and (3) agency.

1. Constraints and Consequences.

A constraint is a condition that is watched every time a constituent variable's value is modified.  Any time a constraint is broken, what happens depends on if there is a consequence specified or not.  If not, the current function is halted and any effects it was attempting are cancelled.  On the other hand, a consequence is code to be executed when a respective constraint is broken. This code may do whatever is appropriate under the circumstances and then may optionally halt/cancel or allow continued execution.

Similar to the Ada language and the Sparc extension to Ada, MBL's constraints may be used for proving correctness thereby ensuring zero software defects.  However, consequences go farther by providing an ability to self-heal a malformed process.

2. Objective Execution
The concept of objective execution is essentially the inverse of constraints and consequences.  Traditional business processing involves process flows where one step leads to the next with optional branching and merging along the way, as illustrated by process flow diagrams.  While this remains possible in MBL, objective execution provides a method of triggering a processing step when and only when specific conditions are met.  The advantage of this approach is that it will take appropriate actions when and only when it is appropriate to do so and regardless of how those pre-requisite conditions came about.  In this way, not only will do the right thing even under unforseen circumstances.  Conversely, traditional process flows tend to deal with mishaps by passing increasingly corrupted data from one step the next.

The fundamental differences between objective execution and constraints & consequences is that objective execution always has a consequence is executes that consequence whent he condition is met, as where constrains may or may not have a consequence and executes the consequence if the condition is not met.

4. Agency

Agency is a feature whereby the software is allowed to make decisions in processes based on established constraints and interests.  For example, instead of assigning a variable a specific value, such as `price = $5`, the program could specify options, such as `price = $5 or $10`. In this case, MBL must make a choice on which value to use.  MBL will do so by finding a choice that does not lead to the breaking of any constraint and works toward specified interests (such as higher profitability).  This is where Artificial Intelligence is employed to forcast in order to make the best selection.  

Additionally, Agency may be used to resolve ambiguities.  For example, if two withdrawals from an account are requested simultaneously but the balance is only sufficient to allow one or the other, a decision must be made.  Using agency to do this will do so according to prescribed constrains and toward interests.  In this case, the interest might be retaining the highest possible balance and MBL would thereby allow the smaller of the two withdrawals.

## Disaster Recovery

In the event of a localized disaster, such as a fire or flood, business data and the software used to interface with and process that data need to remain available and functional.  The usual solution is to have servers in a remote location with identical copies of all data and software on them, waiting to be turned on when and if required.  Depending on the needs of the organization, this could require one or more disaster recovery sites. The down sides to this conventional approach is: (1) it takes time to revert to a disaster recovery location; (2) the switch to the disaster recovery location does not always work; and (3) the expensive server hardware at each disaster recovery location sits unused until a disaster occurs.

MBL solves these problems by integrating servers at all locations into a singular mesh.  MBL programs are run across them all at once.  The softare and data are kept redundant across locations at all times, by default.  Therefore, the result of a disaster in one location merely leads to a performance degredation.  There is no time lost or risk of failure in switching to a disaster recovery location.

## Auditability

Audits are a burden for evey organization.  Particularly in the finance industry, there are numerous audit agencies and frequent demands for data and the explanation thereof.  However for any business, the Sarbanes Oxley legislation mandates pervaisive record keepting and the IRS could audit at any time.  This typically requires expensive human resources being removed from other projects to research, identify, and package information for auditors.  This research sometimes ends in the realization that required data is unavailable for is in some jaw dropping way, not right.

MBL solves these problems through three mechanisms: (1) data safety, (2) temporal data storage, and (3) tree graph data recovery.  

Two features of MBL's Data Safety may be used by an organization's Compliance Department to prove and ensure data is always correct (constraints & consequences and objective execution).  

Furthermore, all long term storage in the MBL mesh data store are stored according to when each data value was changed and precisely when (temporally stored).  In this regard, changes to the processes that make those changes are also temporally stored.  This allows for perfect reconstruction of how and why every piece of data was changed over time.  Contrast this with the conventional approach is merely saving copies of reports and such, at various snapshots in time.

Finally, data are kept in a tree graph form, which is more or less amorphous such that data may be retrieved by means of its relationship to each other.  This allows for the ability to ask what you want to see without regard for where it might be.  Conventionally, an organization may spent many man-hours searching through folders or other historical data repositories trying to reconstruct historic data and produce it int he format requested by auditors.

## Resilience to Changes

Traditionally, software is written as a matter of procedures expecting data in particular places and structured in particular ways to support those procedures.  Therefore, when changes are made to business processes, it is not only necessary to modify the procedures but also the relative data structures and to develop a data migration process to convert from the old to new structure.  Furthermore, modifications in surrounding procedures must often be adjusted for compatibility.

In MBL, the only concern is the specific business process changes to be implemented.  The graph structure of the data means that it is stored in an amorphous structure.  The structure a procedure requires it in may be pulled from and pushed to that same amorphous graph, regardless.  Further, alterations to surrounding procedures should be unnecessary due to the nature of objective execution.  That is, a procedure will execute when the conditions in data are appropriate for it to execute, regardless of how that data became so.  

This is important for MBL because MBL is a "living" language.  As where most programming languages are written (compiled if appropriate) and then executed, MBL code is generally not manually initiated.  Once put into place, it executes when the conditions it is waiting for occurs and it does this continually.  There is no starting or stopping, per say.  It just "lives".  And it lives on a peer-to-peer mesh, such that even intentional malice or natural disasters will find it very hard to stop its operaton.

To maintain control over this, the programmer may implement a flag as part of its condition to turn on/off execution.

## Fast Onboarding of New Developers

The talent pool for existing programming languages are already limited.  Recruitment of business analysts and software developers is already a challenge.  When institutional knowledge is added to understand the specifics of the tools, data structures, methods, etc. are woven in, the onboarding of new developers can be expensive and time consuming.

Learning MBL is made exceptionally simple with its focus on high readability, as the following example illustrates.  The goal is that a non-programmer could easily understand the processes described.

As for high level language with minimal 
```mbl
service ship_order( order[paid >= order.balance and product.instock = true and ship_date is Nothing]  ):
  order.shippable = true
```

The above should clearly illustrate that, any time there is an order that is paid in full, is in stock, but is not yet shipped then mark it as shippable.  In the shipping department, there would likely be an interface that shows all orders where shippable is true.  And, as they physically beginng the shipping process of each, they assign the ship_date accordingly.
In MBL, there is seldom any though required for processes but merely what should be done, under given circumstances.  This should greatly reduce the need for skill or intelligence.

Further, one need not worry about connecting to a database or identifying data within a database but just what you are looking for based on characteristics of it.  In the above example, it's just orders where the balance is paid, the product is in stock, and the order has not yet been shipped.

The only institutional knowledge left to worry about is corporate culture, personalities, and the nature of the business itself.  As for technical knowledge, anyone with knowledge of the business should readily understand and quickly learn to adapt the code.  Again, the emphasis is on if the employee knows the business.

## Unlimited Scalability

MBL code is executed across the mesh network.  In fact, even on a single server, MBL would distribute itself into multiple units, each with limited memory resources operating on its own process.  The work of any MBL programming will automatically distrube across this.  Redundancies will be automatically implemented according to preferences and availability.  Therefore, scaling will work both up and out based on the hardware made available to the mesh.

To add capacity, just think in terms of adding the capacity.  So long as MBL is installed and running, it will use whatever capacity has been authorized to it, in its configuration.  Similarly, removing capacity is also just a matter of removing the physical or virtual hardware with that capacity.

## High Developer Performance

Developer performance is achieve through 

## High Execution Performance

## Enterprise Interfaces

# Design Concepts

I take inspiration from two languages: SQL, ADA, Python, and Javascript.  SQL illustrates that it is more or less possible for a developer to specify merely the current and desired states of data and have the SQL engine come up with how to transation data between those two points.  One of the most important principles to work that is fast, simple, and less error prone is to let the language do as much work for you, as it can.  As for ADA, it illustrates how data quality can be increased and even proven through specification of constraints between data.  Both Python and Javascript demonstrate the power of flexible data structures.  Python further illustrates clarity in syntax while python illustrates the power of proto-type object-orientation over conventional object-orientation in languages like C++, Java, or Python.  These serve as guiding lessons, each of which I think we can take even farther than illustrated in thiese inspirating languages.

In terms of feature completeness for a business language, I want to begin with some obviously needed capabilities.  As for two very useful but near completely neglected capabilities are date/time and money data types.  Other than a coupel exceptional libraries (such as date.js) for Javascript, there isn't even decent library support for dates and times in any other language.  As for money, we are typically forced to use integers to represent the number of pennies (or whatever the lowest deniminator is for the currency type) as arithmetic even in types meant for money tend to be limited and erroneous.  For example, the "Money" type in SQL Server which does little more than hold a number with two digits after the decimal and leads to errors of precision in arithmatic operations.  

In addition to this, feature completeness requires a few other capabilities that tend to be supported but can be simplified and smoothed out, nonetheless.  The can be applied in a default function libraries including but not limited to: web services, email, file transfer, encryption, and report parsing and production (flat, spreadsheet, and PDF files).

## Programing Structure

Programs in MBL are organized into objects, inspired by and similarly functional to Javascript objects.  However in MBL, an "unflavored" object has no pollution in its namespace, scopes cascades, and proto-typing also cascades.  So there is a global object that is "flovored" with the standard elements of the language itself, including functions to inspect objects and a few basic objects that may be used to "flavor" other objects.

```
  Service amortize( amount; interest; payment; perYear:12; term:360; begin ):
    Constrain( begin ?= Unknown ): begin = T"Next Month 15 Days"
    periods = []
    period = { paymentDate:paymentDate, principalPaid:0, interestPaid:0, principalBalance:amount, interestTotal:0 }
    While( period.principalBalance >= payment ):
      period = new period
      period.interestPaid = payment - (interest% Of amount / perYear)
      period.interestTotal += period.interestPaid
      period.principal = payment - period.interestPaid
      period.principalBalance = period.principalBalance - period.principalPaid
      Append period To periods
    End While
    period = new period
    period.paymentDate += T"1 month"
    period.principalPaid = period.principalBalance
    period.interestPaid:0
    Append period To periods
  End amortize With periods 
  
 loan = { amount:$125,000; interest:4.56; payment:$1,500 }
 payments = amortize( loan.* )
  
```


## Data Types

Text
> A string of bytes that, interfaced through MBL, are accessed as the visible range of ASCII characters with others being interpolated in square brackets.  Literal representations may be written between quotes with interpolations allowed except when the letter "r" (for raw) preceeds the opening quote.  Within square brackets, any string expression may be presented for interpolation.  For example, `"The price of [num] eggs at [price] each is [num*price]."`.

Number
> a real number.  The literal form may include up to one decimal and no more than one comma between every 3 digits left of the decimal. The purpose of this is to write literal numbers in a manner that avoids misinterpretation.  For example, `125,000,000.000` is one-hudred-twenty-five-million.  The commas make careful counting of zeros unnecessary.

Boolean
> Yes or No. This `Yes` and `No` is the literal form and equates to what is often true/false or 1/0, in other languages.  These words are used to enhance clarity in reading.

Time
> Internally, a number of seconds.  This may represent a duration or, if relative to 1 CE, a specific point in time.  Literal form may be heuristically interpreted from between quotes where the opening quote is preceeded by the letter "t" (for time). Or, a time expression may be specified.  For example, `T"2023-06-15 15:30:00"` would understand as the date and time, in 24 hour time.  Where different interpretations are possible, 24 hour time is assumed over alternatives.  Also, time is always UTC, internally so conversions to and from Text would translate between UTC and local time, by default.

Money
> A number (as numbers are described above) that follows defined rules for its (definable) currency type, the default being USDollar.  In literal form, this is a number prefixed with a "$" symbol.  The decimal may be no more than one thousandth of the currency's base which, for USDollar, is one dollar.  For example, `$13,000.00` is $13 thousand dollars.  By default, it is USDollars but you may specify other currencies after, such as this example: `$15,000 Won` for Korean Won, instead of dollars.  


