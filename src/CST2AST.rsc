module CST2AST

import Syntax;
import AST;

import ParseTree;
import String;
import Boolean;

/*
 * Implement a mapping from concrete syntax trees (CSTs) to abstract syntax trees (ASTs)
 *
 * - Use switch to do case distinction with concrete patterns (like in Hack your JS) 
 * - Map regular CST arguments (e.g., *, +, ?) to lists 
 *   (NB: you can iterate over * / + arguments using `<-` in comprehensions or for-loops).
 * - Map lexical nodes to Rascal primitive types (bool, int, str)
 * - See the ref example on how to obtain and propagate source locations.
 */

AForm cst2ast(start[Form] sf) {
  Form f = sf.top; // remove layout before and after form
  return cst2ast(f);
}

AForm cst2ast(frm:(Form)`form <Id name> { <Question* qs> }`) {
  return form("<name>", [cst2ast(q) | (Question) q <- qs], src=frm@\loc); //TODO: src 
}

AQuestion cst2ast(quest:Question q) {
  switch(q) {
  	case (Question)`<Str q> <Id vId> : <Type t>`: return question(unquote("<q>"), id("<vId>", src=vId@\loc), cst2ast(t), src=quest@\loc);
  	case (Question)`<Str q> <Id vId> : <Type t> = <Expr e>`: return compQuestion(unquote("<q>"), id("<vId>", src=vId@\loc), cst2ast(t), cst2ast(e), src=quest@\loc);
 	case (Question)`<Block b>`: return cst2ast(b);
	case (Question)`if (<Expr e>) <Block b1> else <Block b2>`: return ifElse(cst2ast(e), cst2ast(b1), cst2ast(b2));
	case (Question)`if (<Expr e>) <Block b>`: return ifThen(cst2ast(e), cst2ast(b));
	default: throw "Unhandled question: <q>"; 
	}
}

AQuestion cst2ast((Block)`{ <Question* qs> }`) {
	return block([cst2ast(q) | q <- qs]);
}

str unquote(str s) {
	return s[1..-1];
}

AExpr cst2ast(Expr e) {
  switch (e) {
    case (Expr)`<Id x>`: return ref(id("<x>", src=x@\loc), src=x@\loc);
    case (Expr)`<Str s>`: return strlit(unquote("<s>"), src=s@\loc);
    case (Expr)`<Int i>`: return intlit(toInt("<i>"), src=i@\loc);
    case (Expr)`<Bool b>`: { return boollit(fromString("<b>"), src=b@\loc);}
    case (Expr)`(<Expr e>)`: return cst2ast(e);
    case (Expr)`!<Expr e>`: return not(cst2ast(e), src=e@\loc);
    case (Expr)`-<Expr e>`: return neg(cst2ast(e), src=e@\loc);
    case (Expr)`<Expr lhs> * <Expr rhs>`: return mul(cst2ast(lhs), cst2ast(rhs), src=e@\loc); //TODO: loc
    case (Expr)`<Expr lhs> / <Expr rhs>`: return div(cst2ast(lhs), cst2ast(rhs), src=e@\loc);
    case (Expr)`<Expr lhs> + <Expr rhs>`: return add(cst2ast(lhs), cst2ast(rhs), src=e@\loc);
    case (Expr)`<Expr lhs> - <Expr rhs>`: return sub(cst2ast(lhs), cst2ast(rhs), src=e@\loc); //TODO; operator as param?
    case (Expr)`<Expr lhs> \> <Expr rhs>`: return gt(cst2ast(lhs), cst2ast(rhs), src=e@\loc);
    case (Expr)`<Expr lhs> \< <Expr rhs>`: return lt(cst2ast(lhs), cst2ast(rhs), src=e@\loc);
    case (Expr)`<Expr lhs> \<= <Expr rhs>`: return lteq(cst2ast(lhs), cst2ast(rhs), src=e@\loc);
    case (Expr)`<Expr lhs> \>= <Expr rhs>`: return gteq(cst2ast(lhs), cst2ast(rhs), src=e@\loc);
    case (Expr)`<Expr lhs> == <Expr rhs>`: return eql(cst2ast(lhs), cst2ast(rhs), src=e@\loc);
    case (Expr)`<Expr lhs> != <Expr rhs>`: return neq(cst2ast(lhs), cst2ast(rhs), src=e@\loc); //TODO: not (==)
    case (Expr)`<Expr lhs> && <Expr rhs>`: return and(cst2ast(lhs), cst2ast(rhs), src=e@\loc);
    case (Expr)`<Expr lhs> || <Expr rhs>`: return or(cst2ast(lhs), cst2ast(rhs), src=e@\loc);
    default: throw "Unhandled expression: <e>";
  }
}

AType cst2ast(Type t) {
  switch(t) {
  	case (Type)`string`: return strType(); //TODO: alias
  	case (Type)`integer`: return intType();
  	case (Type)`boolean`: return boolType();
  	default: throw "Unhandled type: <t>";
  }
}
