module AST

/*
 * Define Abstract Syntax for QL
 *
 * - complete the following data types
 * - make sure there is an almost one-to-one correspondence with the grammar
 */

data AForm(loc src = |tmp:///|)
  = form(str name, list[AQuestion] questions)
  ; 

data AQuestion(loc src = |tmp:///|)
  = question(str quest, AId varId, AType varType)
  | compQuestion(str quest, AId varId, AType varType, AExpr varExpr)
  | block(list[AQuestion] quests)
  | ifElse(AExpr guard, AQuestion ifBlock, AQuestion elseBlock) //TODO: just question?
  | ifThen(AExpr guard, AQuestion ifBlock) 
  ; 

data AExpr(loc src = |tmp:///|)
  = ref(AId id)
  | strlit(str strVal)
  | intlit(int intVal)
  | boollit(bool boolVal)
  | not(AExpr expr)
  | neg(AExpr expr)
  | mul(AExpr lhs, AExpr rhs)
  | div(AExpr lhs, AExpr rhs)
  | add(AExpr lhs, AExpr rhs)
  | sub(AExpr lhs, AExpr rhs)
  | gt(AExpr lhs, AExpr rhs)
  | lt(AExpr lhs, AExpr rhs)
  | lteq(AExpr lhs, AExpr rhs)
  | gteq(AExpr lhs, AExpr rhs)
  | eql(AExpr lhs, AExpr rhs)
  | neq(AExpr lhs, AExpr rhs)
  | and(AExpr lhs, AExpr rhs)
  | or(AExpr lhs, AExpr rhs)
  ;

data AId(loc src = |tmp:///|)
  = id(str name);

data AType(loc src = |tmp:///|)
  = strType()
  | intType()
  | boolType(); 
