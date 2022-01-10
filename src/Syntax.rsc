module Syntax

extend lang::std::Layout;
extend lang::std::Id;

/*
 * Concrete syntax of QL
 */

start syntax Form 
  = "form" Id "{" Question* "}"; 

// TODO: question, computed question, block, if-then-else, if-then
syntax Question
  = @Foldable StrLiteral Id ":" Type //TODO: str
  | StrLiteral Id ":" Type "=" Expr 
  | Block
  | "if" "(" Expr ")" Block "else" Block
  | "if" "(" Expr ")" Block
  ; 
  
syntax Block
  = "{" Question* "}" 
  ;

// TODO: +, -, *, /, &&, ||, !, >, <, <=, >=, ==, !=, literals (bool, int, str)
// Think about disambiguation using priorities and associativity
// and use C/Java style precedence rules (look it up on the internet)
syntax Expr 
  = Id \ "true" \ "false" // true/false are reserved keywords.
  | StrLiteral
  | IntLiteral
  | BoolLiteral
  | bracket "(" Expr ")"
  > right "!" Expr
  | right "-" Expr
  > left Expr "*" Expr
  > left Expr "/" Expr //TODO: priorities
  > left Expr "+" Expr
  > left Expr "-" Expr
  > left Expr "\>" Expr
  > left Expr "\<" Expr
  > left Expr "\<=" Expr
  > left Expr "\>=" Expr
  > left Expr "==" Expr
  > left Expr "!=" Expr
  > left Expr "&&" Expr
  > left Expr "||" Expr
  ;
  
  
syntax Type
  = Bool
  | Str
  | Int
  ;  
  
lexical Str = "string"; ///TODO: better , !>>

lexical Int = "integer"; // 

lexical Bool = "boolean"; 

lexical StrLiteral = @category="StringLiteral" [\"] ![\"]* [\"];

lexical IntLiteral = ([\-]?[1-9][0-9]*)|[0];

lexical BoolLiteral = "true" | "false";



