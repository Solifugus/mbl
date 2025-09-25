# MBL v0.5.0 - Time & Advanced Data Types - TODO

## Progress Status: 🚧 IN PROGRESS

### ✅ **COMPLETED**
- [x] **Time Literal Parsing** (@2020-05-15, @14:30:00)
  - ✅ @now support (current timestamp)
  - ✅ Date literals: @2020-05-15 (YYYY-MM-DD format)
  - ✅ Time literals: @14:30:00 (HH:MM:SS format)
  - ✅ DateTime literals: @2020-05-15T14:30:00 (ISO 8601)
  - ✅ Unix timestamp: @1609459200
  - ✅ Text concatenation: "Time: " + time_var
  - ✅ Lexer fixed for ISO 8601 'T' separator
  - ✅ Parser integration complete
  - ✅ Interpreter evaluation with multiple format support
  - ✅ Date arithmetic foundation (daysSinceEpoch, leap years)

### 🔄 **IN PROGRESS**
- [ ] **Time Operations** (date arithmetic, formatting)
  - [ ] Time + Duration arithmetic
  - [ ] Time - Time = Duration
  - [ ] Date component access (year, month, day)
  - [ ] Time formatting methods
  - [ ] Duration calculations

### 📋 **PENDING**
- [ ] **Duration Types** (3 days, 2 hours 30 minutes)
- [ ] **Time Comparisons** (before/after date logic)
- [ ] **Record Types** (structured data containers)
- [ ] **List/Array Data Type**

## Technical Implementation Notes

### Completed Components:
1. **Lexer** (`lexer.zig`): Enhanced scanTime() to handle 'T' separator
2. **Parser** (`parser.zig`): TimeLiteral AST nodes working
3. **Memory** (`memory.zig`): Time struct with UNIX timestamps already exists
4. **Interpreter** (`interpreter.zig`):
   - parseTimeString() with multiple format support
   - performAddition() with Time + Text concatenation
   - Date parsing with daysSinceEpoch() calculation

### Test Files Created:
- `time_test.mbl` - Original test file
- `simple_time_test.mbl` - Basic assignment test
- `clean_time_test.mbl` - No comments version
- `comprehensive_time_test.mbl` - All format testing ✅ WORKING

## Next Session Restart Point
**Current task**: Implementing Time operations (date arithmetic, formatting)
**Last working commit**: Time literal parsing complete
**Test status**: All time literal formats working correctly

---
*Generated during MBL v0.5.0 development session*