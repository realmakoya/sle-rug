module Check

import AST;
import Resolve;
import Message; // see standard library


data Type
  = tint()
  | tbool()
  | tstr()
  | tunknown()
  ;

// the type environment consisting of defined questions in the form 
alias TEnv = rel[loc def, str name, str label, Type \type];

// To avoid recursively traversing the form, use the `visit` construct
// or deep match (e.g., `for (/question(...) := f) {...}` ) 
TEnv collect(AForm f) {
  TEnv outEnv = {};
  visit(f) {
  	case question(str quest, AId varId, AType varType): outEnv += <varId.src, varId.name, quest, getTypeFromAType(varType)>;
  	case compQuestion(str quest, AId varId, AType varType, _): outEnv += <varId.src, varId.name, quest, getTypeFromAType(varType)>;
  }
  return outEnv; 
}

Type getTypeFromAType(AType t){
  switch(t) {
  	case strType(): return tstr();
  	case intType(): return tint();
  	case boolType(): return tbool();
  	default: return tunknown(); 
 }
}

set[Message] check(AForm f, TEnv tenv, UseDef useDef) {
  set[Message] outMsgs = {};
  for (q <- f.questions) {
  	outMsgs += check(q, tenv, useDef);
  }
  return outMsgs; 
}

set[Message] checkDiffTypes(loc qLoc, str qName, Type qType, TEnv tenv) {
	if (<_, name, _, t> <- tenv, t != qType, name == qName) {
		return {error("Questions with the same name cannot have different types", qLoc)}; //TODO: better?
	}
	return {};
}

set[Message] checkDupLabels(loc qLoc, str qName, str qLabel, TEnv tenv) {
	if (<_, name, label, _> <- tenv, name != qName, label == qLabel) { //TODO: check type?
		return {warning("Duplicate labels for different messages", qLoc)};
	}
	return {};
} 

set[Message] checkDiffLabels(loc qLoc, str qName, str qLabel, TEnv tenv) {
	if (<_, name, label, _> <- tenv, name == qName, label != qLabel) { //TODO: check type?
		return {warning("Same question with different labels", qLoc)};
	}
	return {};
}

// Checks:
// - Error: same question name declared but different types
// - Warning: duplicate labels (for different questions)
// - Error: expression and computed question types don't match
// - Warning: different label for same question
set[Message] check(AQuestion q, TEnv tenv, UseDef useDef) {
  set[Message] outMsgs = {};
  switch(q) {
  	case question(str quest, AId varId, AType varType): {
  		outMsgs += checkDiffTypes(q.src, varId.name, getTypeFromAType(varType), tenv);
  		outMsgs += checkDupLabels(q.src, varId.name, quest, tenv);
  		 outMsgs += checkDiffLabels(q.src, varId.name, quest, tenv);
  	}
  	case compQuestion(str quest, AId varId, AType varType, AExpr varExpr): {
  		outMsgs += checkDiffTypes(q.src, varId.name, getTypeFromAType(varType), tenv);
  		outMsgs += checkDupLabels(q.src, varId.name, quest, tenv);
  		outMsgs += checkDiffLabels(q.src, varId.name, quest, tenv);
  		outMsgs += check(varExpr, tenv, useDef);
  		if (getTypeFromAType(varType) != typeOf(varExpr, tenv, useDef)) {
  			outMsgs += {error("Expression type not the same as computed question type", q.src)};
  		}
  	} 
  	case block(list[AQuestion] quests): { 
  		for (curQ <- quests) {
  			outMsgs += check(curQ, tenv, useDef); //Tried using reducer, didn't work...
  		}
  	}
  	case ifElse(AExpr guard, AQuestion ifBlock, AQuestion elseBlock): {
  		outMsgs += check(guard, tenv, useDef);
  		outMsgs += check(ifBlock, tenv, useDef);
  		outMsgs += check(elseBlock, tenv, useDef);
  		if (typeOf(guard, tenv, useDef) != tbool()) {
  			outMsgs += {error("Guard must be of type boolean", guard.src)};
  		}
  	}
  	case ifThen(AExpr guard, AQuestion ifBlock): {
  		outMsgs += check(guard, tenv, useDef);
  		outMsgs += check(ifBlock, tenv, useDef);
  		if (typeOf(guard, tenv, useDef) != tbool()) {
  			outMsgs += {error("Guard must be of type boolean", guard.src)}; 
  		}
  	}
  }
  return outMsgs; 
}

set[Message] checkBinaryOp(loc src, str typeName, Type \type, AExpr lhs, AExpr rhs, TEnv tenv, UseDef useDef) {
	set[Message] outMsgs = {};
	outMsgs += check(lhs, tenv, useDef);
	outMsgs += check(rhs, tenv, useDef);
	outMsgs += { error("Operands must be of the same type", src) | typeOf(lhs, tenv, useDef) != typeOf(rhs, tenv, useDef)}; // Checks if they're different
	outMsgs += { error("Operands must be of type: <typeName>", src) | \type != tunknown() && typeOf(lhs, tenv, useDef) != \type}; // Checks they match the expected type
	return outMsgs;
}

// Check operand compatibility with operators.
// E.g. for an addition node add(lhs, rhs), 
//   the requirement is that typeOf(lhs) == typeOf(rhs) == tint()
// Checks also for use of undeclared question in expression, and unary operators.
set[Message] check(AExpr e, TEnv tenv, UseDef useDef) {
  set[Message] msgs = {};
  switch (e) {
    case ref(AId x): 
      msgs += { error("Undeclared question", x.src) | useDef[x.src] == {} }; 
    case not(AExpr x):
	  msgs += { error("Can only apply \"!\" to a boolean", x.src) | typeOf(x, tenv, useDef) != tbool()};
	case neg(AExpr x):
	  msgs += { error("Can only negate an integer", x.src) | typeOf(x, tenv, useDef) != tint()};
	 case mul(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "integer", tint(), lhs, rhs, tenv, useDef);
	 case div(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "integer", tint(), lhs, rhs, tenv, useDef);
	 case add(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "integer", tint(), lhs, rhs, tenv, useDef);
	 case sub(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "integer", tint(), lhs, rhs, tenv, useDef);
	 case gt(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "integer", tint(), lhs, rhs, tenv, useDef);
	 case lt(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "integer", tint(), lhs, rhs, tenv, useDef);
	 case lteq(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "integer", tint(), lhs, rhs, tenv, useDef);
	 case gteq(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "integer", tint(), lhs, rhs, tenv, useDef);
	 case eql(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "", tunknown(), lhs, rhs, tenv, useDef); // Since eql/neq can be used on any data type, we use tunknown as a placeholder.
	 case neq(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "", tunknown(), lhs, rhs, tenv, useDef); 
	 case and(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "boolean", tbool(), lhs, rhs, tenv, useDef);
	 case or(AExpr lhs, AExpr rhs):
	  msgs += checkBinaryOp(e.src, "boolean", tbool(), lhs, rhs, tenv, useDef);
  }
  return msgs; 
}

// Perhaps having a binop() ADT would have been more concise
Type typeOf(AExpr e, TEnv tenv, UseDef useDef) {
  switch (e) {
    case ref(id(_, src = loc u)): {
      if (<u, loc d> <- useDef, <d, x, _, Type t> <- tenv) {
        return t;
      }
     }
    case strlit(_):
      return tstr();
    case intlit(_):
      return tint();
    case boollit(_):
      return tbool();
    case not(_):
	  return tbool();
	case neg(_):
	  return tint();
    case mul(_, _):
      return tint();
    case div(_, _):
      return tint();
    case add(_, _):
      return tint();
    case sub(_, _):
      return tint();
    case gt(_, _):
      return tbool();
    case lt(_, _):
      return tbool();
    case lteq(_, _):
      return tbool();
    case gteq(_, _):
      return tbool();
    case eql(_, _):
      return tbool();
    case neq(_, _):
      return tbool();	 
    case and(_, _):
      return tbool();	
    case or(_, _):
      return tbool();	
  }
  return tunknown(); 
}

/* 
 * Pattern-based dispatch style:
 * 
 * Type typeOf(ref(id(_, src = loc u)), TEnv tenv, UseDef useDef) = t
 *   when <u, loc d> <- useDef, <d, x, _, Type t> <- tenv
 *
 * ... etc.
 * 
 * default Type typeOf(AExpr _, TEnv _, UseDef _) = tunknown();
 *
 */
 
 

