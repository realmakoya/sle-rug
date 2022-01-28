module Transform

import Syntax;
import Resolve;
import AST;

extend lang::std::Id;

import IO;
import ParseTree;

/* 
 * Transforming QL forms
 */
 
 
/* Normalization:
 *  wrt to the semantics of QL the following
 *     q0: "" int; 
 *     if (a) { 
 *        if (b) { 
 *          q1: "" int; 
 *        } 
 *        q2: "" int; 
 *      }
 *
 *  is equivalent to
 *     if (true) q0: "" int;
 *     if (true && a && b) q1: "" int;
 *     if (true && a) q2: "" int;
 *
 * Write a transformation that performs this flattening transformation.
 *
 */
 
 
// Flattening: Normalises the QL Form into the specified if-then format seen above.
// Uses pattern-based function dispatch to recursively flatten nested if/if-else statements and transform
// questions/computed questions. A visit statement or other pattern-based methodswith an insert action 
// could have been used as well, but I was not sure how to propagate the guard in this case.

list[AQuestion] flattenQ(i: ifThen(AExpr guard, AQuestion ifBlock), AExpr prevGuard) {
	list[AQuestion] ifBl = flattenQ(ifBlock, and(prevGuard, guard));
	return ifBl;
}
 
list[AQuestion] flattenQ(ie: ifElse(AExpr guard, AQuestion ifBlock, AQuestion elseBlock), AExpr prevGuard) {
	list[AQuestion] ifBl = flattenQ(ifBlock, and(prevGuard, guard));
	list[AQuestion] elseBl = flattenQ(elseBlock, and(prevGuard, not(guard)));
	return ifBl + elseBl; 
}

list[AQuestion] flattenQ(block(list[AQuestion] quests), AExpr guard) {
	list[AQuestion] blQs = ([] | it + flattenQ(q, guard) | q <- quests);
	return blQs; 
}

AQuestion flattenQ(cq: compQuestion, AExpr guard) {
	return ifThen(guard, block([cq])); 
}

AQuestion flattenQ(q: question, AExpr guard) {
	return ifThen(guard, block([q]));
}
 

AForm flatten(AForm f) {
	list[AQuestion] flattened = [];
	for (q <- f.questions) {
		flattened += flattenQ(q, boollit(true)); // if(true) is default guard
	}
	f.questions = flattened;
	return f;
}

/* Rename refactoring:
 *
 * Write a refactoring transformation that consistently renames all occurrences of the same name.
 * Use the results of name resolution to find the equivalence class of a name.
 *
 */
 
 set[loc] toRename(loc useOrDef, UseDef useDef) {
 	loc def = |tmp:///|;
 	if (<useOrDef, loc d> <- useDef) {
 		def = d;
 	} else {
 		def = useOrDef;
 	}
 	set[loc] toRenameLs = {use | <loc use, loc d> <- useDef, d == def} + def;
 	return toRenameLs;
 }
 
 start[Form] rename(start[Form] f, loc useOrDef, str newName, UseDef useDef) {
   // Check if it's a use or definining occurence
   set[loc] toRenameLs = toRename(useOrDef, useDef);
   return visit(f) {
   	case Id x => [Id] newName
   		when x@\loc in toRenameLs
   }
 } 
 
 
 

