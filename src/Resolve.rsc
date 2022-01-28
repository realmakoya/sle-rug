module Resolve

import AST;

/*
 * Name resolution for QL
 */ 


// modeling declaring occurrences of names
alias Def = rel[str name, loc def];

// modeling use occurrences of names
alias Use = rel[loc use, str name];

alias UseDef = rel[loc use, loc def];

// the reference graph
alias RefGraph = tuple[
  Use uses, 
  Def defs, 
  UseDef useDef
]; 

RefGraph resolve(AForm f) = <us, ds, us o ds>
  when Use us := uses(f), Def ds := defs(f);

Use uses(AForm f) {
  return { <id.src, id.name> | /ref(AId id) := f}; 
}

Def defs(AForm f) {
  return { <varId.name, varId.src> | /question(_, AId varId, _) := f} +
  			{<varId.name, varId.src> |/compQuestion(_, AId varId, _, _) := f}; //TODO: simplify, add WHOLE q def
}