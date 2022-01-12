module Check

import AST;
import Resolve;
import Message; // see standard library
import Set;
import IO;

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
  	case q:question(str quest, AId varId, AType varType): outEnv += <q.src, varId.name, quest, getTypeFromAType(varType)>;
  	case q:compQuestion(str quest, AId varId, AType varType, _): outEnv += <q.src, varId.name, quest, getTypeFromAType(varType)>;
  }
  return outEnv; 
}

Type getTypeFromAType(AType t){
  switch(t) {
  	case strType(): return tstr();
  	case intType(): return tint();
  	case boolType(): return tbool();
  	default: return tunknown(); //TODO: best?
 }
}

set[Message] check(AForm f, TEnv tenv, UseDef useDef) {
  // TODO: ref to undefined questions, condition not boolean, invalid operand types to operator, duplicate quest diff type
  // Warnings: Same label different questions, diff labels for occurences same question
  set[Message] outMsgs = {};
  //println("Here now!");
  for (q <- f.questions) {
    //iprintln("Here!");
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

// - produce an error if there are declared questions with the same name but different types.
// - duplicate labels should trigger a warning 
// - the declared type computed questions should match the type of the expression.
set[Message] check(AQuestion q, TEnv tenv, UseDef useDef) {
  set[Message] outMsgs = {};
  switch(q) {
  	case question(str quest, AId varId, AType varType): {
  		outMsgs += checkDiffTypes(q.src, varId.name, getTypeFromAType(varType), tenv);
  		outMsgs += checkDupLabels(q.src, varId.name, quest, tenv);
  	}
  	case compQuestion(str quest, AId varId, AType varType, AExpr varExpr): {
  		outMsgs += checkDiffTypes(q.src, varId.name, getTypeFromAType(varType), tenv);
  		outMsgs += checkDupLabels(q.src, varId.name, quest, tenv);
  		outMsgs += check(varExpr, tenv, useDef);
  		if (getTypeFromAType(varType) != typeOf(varExpr, tenv, useDef)) {
  			outMsgs += {error("Expression type not the same as computed question type", q.src)};
  		}
  	} //TODO: other checks
  	case block(list[AQuestion] quests): { 
  		//println("Blocks!");
  		//println("CurCheck: <quests>");
  		for (curQ <- quests) {
  			outMsgs += check(curQ, tenv, useDef); //Tried using reducer, didn't work...
  		}
  		//println("After?");
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
  		//println("Ifbloc: <ifBlock>");
  		if (typeOf(guard, tenv, useDef) != tbool()) {
  		  	//println("<typeOf(guard, tenv, useDef)>");
  			outMsgs += {error("Guard must be of type boolean", guard.src)}; //TODO: code rep
  		}
  	}
  }
  return outMsgs; 
}

// Check operand compatibility with operators.
// E.g. for an addition node add(lhs, rhs), 
//   the requirement is that typeOf(lhs) == typeOf(rhs) == tint()
set[Message] check(AExpr e, TEnv tenv, UseDef useDef) {
  set[Message] msgs = {};
  switch (e) {
    case ref(AId x): 
      msgs += { error("Undeclared question", x.src) | useDef[x.src] == {} }; //TODO: literals? 
    case not(AExpr x):
	  msgs += { error("Can only apply \"!\" to a boolean", x.src) | typeOf(x, tenv, useDef) != tbool()};
	case neg(AExpr x):
	  msgs += { error("Can only negate an integer", x.src) | typeOf(x, tenv, useDef) != tint()};
	 case mul(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only multiply integers", lhs.src) | !(typeOf(lhs, tenv, useDef) == tint() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
	 case div(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only divide integers", lhs.src) | !(typeOf(lhs, tenv, useDef) == tint() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
	 case add(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only add integers", lhs.src) | !(typeOf(lhs, tenv, useDef) == tint() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
	 case sub(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only subtract integers", lhs.src) | !(typeOf(lhs, tenv, useDef) == tint() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
	 case gt(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only compare order of integers", lhs.src) | !(typeOf(lhs, tenv, useDef) == tint() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
	 case lt(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only compare order of integers", lhs.src) | !(typeOf(lhs, tenv, useDef) == tint() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
	 case lteq(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only compare order of integers", lhs.src) | !(typeOf(lhs, tenv, useDef) == tint() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
	 case gteq(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only compare order of integers", lhs.src) | !(typeOf(lhs, tenv, useDef) == tint() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
	 case eql(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only compare equality of similar types", lhs.src) | typeOf(lhs, tenv, useDef) != typeOf(rhs, tenv, useDef)};
	 case neq(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only compare equality of similar types", lhs.src) | typeOf(lhs, tenv, useDef) != typeOf(rhs, tenv, useDef)};	 
	 case and(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only perform \"and\" on booleans", lhs.src) | !(typeOf(lhs, tenv, useDef) == tbool() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
	 case or(AExpr lhs, AExpr rhs):
	  msgs += { error("Can only perform \"or\" on booleans", lhs.src) | !(typeOf(lhs, tenv, useDef) == tbool() && typeOf(lhs, tenv, useDef) == typeOf(rhs, tenv, useDef))};
  }
  return msgs; 
}

Type typeOf(AExpr e, TEnv tenv, UseDef useDef) {
  //println("Expr: <e>");
  switch (e) {
    case ref(id(_, src = loc u)): {
      //println("Ref! src = <u>");
      if (<u, loc d> <- useDef, <d, x, _, Type t> <- tenv) {
        //println("Ref, type = <t>");
        return t;
      }
     }
    case strlit(_):
      return tstr();
    case intlit(_):
      return tint();
    case boollit(_):
      return tbool;
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
 
 

