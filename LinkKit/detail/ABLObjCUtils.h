// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

// This ObjC macro provides failing implementation for unimplemented designated
// initializers inherited from a superclass.
#define ABL_NOT_IMPLEMENTED_INITIALIZER(initName) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wobjc-designated-initializers\"") \
- (instancetype)initName \
{ \
NSAssert2(NO, @"%@ is not the designated initializer for instances of %@.", \
NSStringFromSelector(_cmd), \
NSStringFromClass([self class])); \
return nil; \
} \
_Pragma("clang diagnostic pop")
