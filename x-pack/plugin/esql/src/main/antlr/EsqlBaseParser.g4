/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0; you may not use this file except in compliance with the Elastic License
 * 2.0.
 */
parser grammar EsqlBaseParser;

@header {
/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0; you may not use this file except in compliance with the Elastic License
 * 2.0.
 */
}

options {
  superClass=ParserConfig;
  tokenVocab=EsqlBaseLexer;
}

singleStatement
    : query EOF
    ;

query
    : sourceCommand                 #singleCommandQuery
    | query PIPE processingCommand  #compositeQuery
    ;

sourceCommand
    : explainCommand
    | fromCommand
    | rowCommand
    | showCommand
    // in development
    | {this.isDevVersion()}? metricsCommand
    ;

processingCommand
    : evalCommand
    | whereCommand
    | keepCommand
    | limitCommand
    | statsCommand
    | sortCommand
    | dropCommand
    | renameCommand
    | dissectCommand
    | grokCommand
    | enrichCommand
    | mvExpandCommand
    | joinCommand
    // in development
    | {this.isDevVersion()}? inlinestatsCommand
    | {this.isDevVersion()}? lookupCommand
    | {this.isDevVersion()}? changePointCommand
    | {this.isDevVersion()}? insistCommand
    ;

whereCommand
    : WHERE booleanExpression
    ;

booleanExpression
    : NOT booleanExpression                                                      #logicalNot
    | valueExpression                                                            #booleanDefault
    | regexBooleanExpression                                                     #regexExpression
    | left=booleanExpression operator=AND right=booleanExpression                #logicalBinary
    | left=booleanExpression operator=OR right=booleanExpression                 #logicalBinary
    | valueExpression (NOT)? IN LP valueExpression (COMMA valueExpression)* RP   #logicalIn
    | valueExpression IS NOT? NULL                                               #isNull
    | matchBooleanExpression                                                     #matchExpression
    ;

regexBooleanExpression
    : valueExpression (NOT)? kind=LIKE pattern=string
    | valueExpression (NOT)? kind=RLIKE pattern=string
    ;

matchBooleanExpression
    : fieldExp=qualifiedName (CAST_OP fieldType=dataType)? COLON matchQuery=constant
    ;

valueExpression
    : operatorExpression                                                                      #valueExpressionDefault
    | left=operatorExpression comparisonOperator right=operatorExpression                     #comparison
    ;

operatorExpression
    : primaryExpression                                                                       #operatorExpressionDefault
    | operator=(MINUS | PLUS) operatorExpression                                              #arithmeticUnary
    | left=operatorExpression operator=(ASTERISK | SLASH | PERCENT) right=operatorExpression  #arithmeticBinary
    | left=operatorExpression operator=(PLUS | MINUS) right=operatorExpression                #arithmeticBinary
    ;

primaryExpression
    : constant                                                                          #constantDefault
    | qualifiedName                                                                     #dereference
    | functionExpression                                                                #function
    | LP booleanExpression RP                                                           #parenthesizedExpression
    | primaryExpression CAST_OP dataType                                                #inlineCast
    ;

functionExpression
    : functionName LP (ASTERISK | (booleanExpression (COMMA booleanExpression)* (COMMA mapExpression)?))? RP
    ;

functionName
    : identifierOrParameter
    ;

mapExpression
    : LEFT_BRACES entryExpression (COMMA entryExpression)* RIGHT_BRACES
    ;

entryExpression
    : key=string COLON value=constant
    ;

dataType
    : identifier                                                                        #toDataType
    ;

rowCommand
    : ROW fields
    ;

fields
    : field (COMMA field)*
    ;

field
    : (qualifiedName ASSIGN)? booleanExpression
    ;

fromCommand
    : FROM indexPattern (COMMA indexPattern)* metadata?
    ;

indexPattern
    : (clusterString COLON)? indexString
    ;

clusterString
    : UNQUOTED_SOURCE
    | QUOTED_STRING
    ;

indexString
    : UNQUOTED_SOURCE
    | QUOTED_STRING
    ;

metadata
    : METADATA UNQUOTED_SOURCE (COMMA UNQUOTED_SOURCE)*
    ;

metricsCommand
    : DEV_METRICS indexPattern (COMMA indexPattern)* aggregates=aggFields? (BY grouping=fields)?
    ;

evalCommand
    : EVAL fields
    ;

statsCommand
    : STATS stats=aggFields? (BY grouping=fields)?
    ;

aggFields
    : aggField (COMMA aggField)*
    ;

aggField
    : field (WHERE booleanExpression)?
    ;

qualifiedName
    : identifierOrParameter (DOT identifierOrParameter)*
    ;

qualifiedNamePattern
    : identifierPattern (DOT identifierPattern)*
    ;

qualifiedNamePatterns
    : qualifiedNamePattern (COMMA qualifiedNamePattern)*
    ;

identifier
    : UNQUOTED_IDENTIFIER
    | QUOTED_IDENTIFIER
    ;

identifierPattern
    : ID_PATTERN
    | parameter
    ;

constant
    : NULL                                                                              #nullLiteral
    | integerValue UNQUOTED_IDENTIFIER                                                  #qualifiedIntegerLiteral
    | decimalValue                                                                      #decimalLiteral
    | integerValue                                                                      #integerLiteral
    | booleanValue                                                                      #booleanLiteral
    | parameter                                                                         #inputParameter
    | string                                                                            #stringLiteral
    | OPENING_BRACKET numericValue (COMMA numericValue)* CLOSING_BRACKET                #numericArrayLiteral
    | OPENING_BRACKET booleanValue (COMMA booleanValue)* CLOSING_BRACKET                #booleanArrayLiteral
    | OPENING_BRACKET string (COMMA string)* CLOSING_BRACKET                            #stringArrayLiteral
    ;

parameter
    : PARAM                        #inputParam
    | NAMED_OR_POSITIONAL_PARAM    #inputNamedOrPositionalParam
    ;

identifierOrParameter
    : identifier
    | parameter
    ;

limitCommand
    : LIMIT INTEGER_LITERAL
    ;

sortCommand
    : SORT orderExpression (COMMA orderExpression)*
    ;

orderExpression
    : booleanExpression ordering=(ASC | DESC)? (NULLS nullOrdering=(FIRST | LAST))?
    ;

keepCommand
    :  KEEP qualifiedNamePatterns
    ;

dropCommand
    : DROP qualifiedNamePatterns
    ;

renameCommand
    : RENAME renameClause (COMMA renameClause)*
    ;

renameClause:
    oldName=qualifiedNamePattern AS newName=qualifiedNamePattern
    ;

dissectCommand
    : DISSECT primaryExpression string commandOptions?
    ;

grokCommand
    : GROK primaryExpression string
    ;

mvExpandCommand
    : MV_EXPAND qualifiedName
    ;

commandOptions
    : commandOption (COMMA commandOption)*
    ;

commandOption
    : identifier ASSIGN constant
    ;

booleanValue
    : TRUE | FALSE
    ;

numericValue
    : decimalValue
    | integerValue
    ;

decimalValue
    : (PLUS | MINUS)? DECIMAL_LITERAL
    ;

integerValue
    : (PLUS | MINUS)? INTEGER_LITERAL
    ;

string
    : QUOTED_STRING
    ;

comparisonOperator
    : EQ | NEQ | LT | LTE | GT | GTE
    ;

explainCommand
    : EXPLAIN subqueryExpression
    ;

subqueryExpression
    : OPENING_BRACKET query CLOSING_BRACKET
    ;

showCommand
    : SHOW INFO                                                           #showInfo
    ;

enrichCommand
    : ENRICH policyName=ENRICH_POLICY_NAME (ON matchField=qualifiedNamePattern)? (WITH enrichWithClause (COMMA enrichWithClause)*)?
    ;

enrichWithClause
    : (newName=qualifiedNamePattern ASSIGN)? enrichField=qualifiedNamePattern
    ;

//
// In development
//
lookupCommand
    : DEV_LOOKUP tableName=indexPattern ON matchFields=qualifiedNamePatterns
    ;

inlinestatsCommand
    : DEV_INLINESTATS stats=aggFields (BY grouping=fields)?
    ;

joinCommand
    : type=(JOIN_LOOKUP | DEV_JOIN_LEFT | DEV_JOIN_RIGHT) JOIN joinTarget joinCondition
    ;

joinTarget
    : index=indexPattern
    ;

joinCondition
    : ON joinPredicate (COMMA joinPredicate)*
    ;

joinPredicate
    : valueExpression
    ;

changePointCommand
    : DEV_CHANGE_POINT value=qualifiedName (ON key=qualifiedName)? (AS targetType=qualifiedName COMMA targetPvalue=qualifiedName)?
    ;

insistCommand
    : DEV_INSIST qualifiedNamePatterns
    ;
