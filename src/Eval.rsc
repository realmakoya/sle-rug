module Eval

import AST;
import Resolve;

/*
 * Implement big-step semantics for QL
 */
 
// NB: Eval may assume the form is type- and name-correct.


// Semantic domain for expressions (values)
data Value
  = vint(int n)
  | vbool(bool b)
  | vstr(str s)
  ;

// The value environment
alias VEnv = map[str name, Value \value];

// Modeling user input
data Input
  = input(str question, Value \value);
  
Value defaultValue(AType \type) {
	switch(\type) {
		case strType(): return vstr("");
		case intType(): return vint(0);
		case boolType(): return vbool(false);
		default: return vstr(""); //TODO: best way?
	};
}
  
// produce an environment which for each question has a default value
// (e.g. 0 for int, "" for str etc.)
VEnv initialEnv(AForm f) {
  VEnv venv = ();
  visit (f) {
  	case question(_, AId varId, AType varType): venv += (varId.name: defaultValue(varType));
  	case compQuestion(_, AId varId, AType varType, _): venv += (varId.name: defaultValue(varType));
  }
  return venv;
  //return (varId.name: );
}


// Because of out-of-order use and declaration of questions
// we use the solve primitive in Rascal to find the fixpoint of venv.
VEnv eval(AForm f, Input inp, VEnv venv) {
  return solve (venv) {
    venv = evalOnce(f, inp, venv);
  }
}

VEnv evalOnce(AForm f, Input inp, VEnv venv) {
  VEnv newVEnv = venv;
  for (q <- f.questions) {
  	newVEnv = eval(q, inp, newVEnv);
  }
  return newVEnv;
}

VEnv eval(AQuestion q, Input inp, VEnv venv) {
  // evaluate conditions for branching,
  // evaluate inp and computed questions to return updated VEnv
  VEnv newVEnv = venv;
  switch (q) {
  	case question(_, AId varId, _): if (varId.name == inp.question) newVEnv[varId.name] = inp.\value;
  	case compQuestion(_, AId varId, _, AExpr varExpr): newVEnv[varId.name] = eval(varExpr, newVEnv);
  	case block(list[AQuestion] quests): {
  		for (qu <- quests) {
  			newVEnv = eval(qu, inp, newVEnv);
  		}
  	} 
  	case ifElse(AExpr guard, AQuestion ifBlock, AQuestion elseBlock): {
  		if (eval(guard, newVEnv).b) {
  			newVEnv = eval(ifBlock, inp, newVEnv);
  		} else {
  			newVEnv = eval(elseBlock, inp, newVEnv);
  		}
  	}
  	case ifThen(AExpr guard, AQuestion ifBlock): {
  		if (eval(guard, newVEnv).b) {
  			newVEnv = eval(ifBlock, inp, newVEnv);
  		}
  	}
  }
  return newVEnv; 
}

Value eval(AExpr e, VEnv venv) {
  switch (e) {
    case ref(id(str x)): return venv[x];
    case strlit(str strVal): return vstr(strVal);
    case intlit(int intVal): return vint(intVal);
    case boollit(bool boolVal): return vbool(boolVal);
    case not(AExpr expr): return vbool(!eval(expr, venv).b);
    case neg(AExpr expr): return vint(-eval(expr, venv).n); //TODO: works?
    case mul(AExpr lhs, AExpr rhs): return vint(eval(lhs, venv).n * eval(rhs, venv).n);
    case div(AExpr lhs, AExpr rhs): return vint(eval(lhs, venv).n / eval(rhs, venv).n);
    case add(AExpr lhs, AExpr rhs): return vint(eval(lhs, venv).n + eval(rhs, venv).n);
    case sub(AExpr lhs, AExpr rhs): return vint(eval(lhs, venv).n - eval(rhs, venv).n);
    case gt(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).n > eval(rhs, venv).n);
    case lt(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).n < eval(rhs, venv).n);
    case lteq(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).n <= eval(rhs, venv).n);
    case gteq(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).n >= eval(rhs, venv).n);
    case eql(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv) == eval(rhs, venv));
    case neq(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv) != eval(rhs, venv));
    case and(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).b && eval(rhs, venv).b);
    case or(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).b || eval(rhs, venv).b);
    default: throw "Unsupported expression <e>";
  }
}