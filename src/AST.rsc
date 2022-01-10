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
  = question(str quest, str varName, AType varType)
  | question(str quest, str varName, AType varType, AExpr expr)
  | question(list[AQuestion] block)
  | question(AExpr guard, list[AQuestion] ifBlock, list[AQuestion] elseBlock)
  | question(AExpr guard, list[AQuestion] ifBlock) 
  ; 

data AExpr(loc src = |tmp:///|)
  = ref(AId id)
  ;

data AId(loc src = |tmp:///|)
  = id(str name);

data AType(loc src = |tmp:///|);
