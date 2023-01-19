# mbl
Modern Business Language

# Overviev

As tragic as it sounds, there doesn't appear to have been a programming language developed specifically for business since COBOL was conceived in 1959.  I've been writing software singe about 1984 and also truly feel is if we've regresses in many ways.  As computer hardware has increased in performance, by many orders of mangnitudes, operating systems and software have made them considerably slower, wasteful of memory/storage, and less reliable in most areas.  Furthermore, there have been very few and minor advantages in terms of functionality or capabilities in exchange for this.  In fact, reliability and quality has clearly worsened.

While these problems persist and consistently worsen in systems software and, particularly, in applications software, I want to address the needs for business software, in this project.  In so doing, I hope reduce (not increase) the learning curve as well as both speed of development and maintainability of business software while adding some of the more obviously capabilities we should have had in a business programming language, decades ago.

In the most general terms, the priorities of this new language are:

* Low Learning Curve and Rapid Development
* High Readaibility and Maintainability
* Data Safety and Process Quality
* Minimal Work with Maximum Flexibility
* Feature Complete for All Common Business Needs

Note: The language itself is case-insensitive but, for illustrative purposes, I capitalize the first letter of build-in objects to differentiate from programmer-supplied elements of the syntax.

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


