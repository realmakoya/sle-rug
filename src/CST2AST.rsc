module CST2AST

import Syntax;
import AST;

import ParseTree;
import String;
import Boolean;
import IO;

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

AForm cst2ast((Form)`form <Id name> { <Question* qs> }`) {
  //println("test");
  return form("<name>", [cst2ast(q) | (Question) q <- qs]); //TODO: src 
}

AQuestion cst2ast(Question q) {
  switch(q) {
  	case (Question)`<Str q> <Id id> : <Type t>`: return question(unquote("<q>"), "<id>", cst2ast(t));
  	case (Question)`<Str q> <Id id> : <Type t> = <Expr e>`: return compQuestion(unquote("<q>"), "<id>", cst2ast(t), cst2ast(e));
 	case (Question)`<Block b>`: return cst2ast(b);
	case (Question)`if (<Expr e>) <Block b1> else <Block b2>`: return ifThen(cst2ast(e), cst2ast(b1), cst2ast(b2));
	case (Question)`if (<Expr e>) <Block b>`: return ifElse(cst2ast(e), cst2ast(b));
	default: throw "Unhandled question: <q>"; //TODO: src
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
    case (Expr)`<Bool b>`: { println("<b>"); return boollit(fromString("<b>"));}
    case (Expr)`(<Expr e>)`: return cst2ast(e);
    case (Expr)`!<Expr e>`: return not(cst2ast(e));
    case (Expr)`-<Expr e>`: return neg(cst2ast(e));
    case (Expr)`<Expr lhs> * <Expr rhs>`: return mul(cst2ast(lhs), cst2ast(rhs));
    case (Expr)`<Expr lhs> / <Expr rhs>`: return div(cst2ast(lhs), cst2ast(rhs));
    case (Expr)`<Expr lhs> + <Expr rhs>`: return add(cst2ast(lhs), cst2ast(rhs));
    case (Expr)`<Expr lhs> - <Expr rhs>`: return sub(cst2ast(lhs), cst2ast(rhs)); //TODO; operator as param?
    case (Expr)`<Expr lhs> \> <Expr rhs>`: return gt(cst2ast(lhs), cst2ast(rhs));
    case (Expr)`<Expr lhs> \< <Expr rhs>`: return lt(cst2ast(lhs), cst2ast(rhs));
    case (Expr)`<Expr lhs> \<= <Expr rhs>`: return lteq(cst2ast(lhs), cst2ast(rhs));
    case (Expr)`<Expr lhs> \>= <Expr rhs>`: return gteq(cst2ast(lhs), cst2ast(rhs));
    case (Expr)`<Expr lhs> == <Expr rhs>`: return eql(cst2ast(lhs), cst2ast(rhs));
    case (Expr)`<Expr lhs> != <Expr rhs>`: return neq(cst2ast(lhs), cst2ast(rhs)); //TODO: not (==)
    case (Expr)`<Expr lhs> && <Expr rhs>`: return and(cst2ast(lhs), cst2ast(rhs));
    case (Expr)`<Expr lhs> || <Expr rhs>`: return or(cst2ast(lhs), cst2ast(rhs));
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
