module Transform

import Syntax;
import Resolve;
import AST;

import IO;

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
 
list[AQuestion] flattenQ(i: ifThen(AExpr guard, AQuestion ifBlock), AExpr prevGuard) {
	list[AQuestion] ifBl = flattenQ(ifBlock, and(prevGuard, guard));
	return ifBl;
}
 
list[AQuestion] flattenQ(ie: ifElse(AExpr guard, AQuestion ifBlock, AQuestion elseBlock), AExpr prevGuard) {
	list[AQuestion] ifBl = flattenQ(ifBlock, and(prevGuard, guard));
	list[AQuestion] elseBl = flattenQ(elseBlock, and(prevGuard, not(guard)));
	return ifBl + elseBl; //TODO: best
}

list[AQuestion] flattenQ(bl: block(list[AQuestion] quests), AExpr guard) {
	list[AQuestion] blQs = ([] | it + flattenQ(q, guard) | q <- quests);
	return blQs; //TODO: best...
}

AQuestion flattenQ(cq: compQuestion, AExpr guard) {
	return ifThen(guard, block([cq])); //TODO: best way?
}

AQuestion flattenQ(q: question, AExpr guard) {
	return ifThen(guard, block([q])); //TODO: best way?
}
 
// Go through 
AForm flatten(AForm f) {
	list[AQuestion] flattened = [];
	for (q <- f.questions) {
		flattened += flattenQ(q, boollit(true)); 
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
 
 start[Form] rename(start[Form] f, loc useOrDef, str newName, UseDef useDef) {
   return f; 
 } 
 
 
 

