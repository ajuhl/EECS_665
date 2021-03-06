%skeleton "lalr1.cc"
%require  "3.0"
%debug
%defines
%define api.namespace {LILC}
%define parser_class_name {LilC_Parser}
%output "lilc_parser.cc"
%token-table

%code requires{
    #include <list>
    #include "symbols.hpp"
    #include "ast.hpp"
    namespace LILC {
        class LilC_Compiler;
        class LilC_Scanner;
    }

// The following definitions is missing when %locations isn't used
# ifndef YY_NULLPTR
#   if defined __cplusplus && 201103L <= __cplusplus
#       define YY_NULLPTR nullptr
#   else
#       define YY_NULLPTR 0
#   endif
# endif

}

%parse-param { LilC_Scanner  &scanner  }
%parse-param { LilC_Compiler &compiler }

%code {
    #include <iostream>
    #include <cstdlib>
    #include <fstream>

    /* include for interoperation between scanner/parser */
    #include "lilc_compiler.hpp"

#undef yylex
#define yylex scanner.yylex
}

/*%define api.value.type variant*/
%union {
	/*
	int intVal;
	std::string * strVal;
	*/
    LILC::SynSymbol * symbolValue;
	LILC::IDToken * idTokenValue;
    LILC::IntLitToken * intTokenValue;
    LILC::StringLitToken * strTokenValue;
	LILC::ASTNode * astNode;
	LILC::ProgramNode * programNode;
	std::list<DeclNode *> * declList;
	LILC::DeclNode * declNode;
    std::list<VarDeclNode *> * varDeclList;
	LILC::VarDeclNode * varDeclNode;
	LILC::TypeNode * typeNode;
	LILC::IdNode * idNode;
    LILC::IntLitNode * intLitNode;
    LILC::StrLitNode * strLitNode;
    LILC::StructDeclNode * structDeclNode;
    LILC::StructBodyNode * structBodyNode;
    LILC::FnDeclNode * fnDeclNode;
    LILC::FormalsNode * formalsNode;
    std::list<FormalsNode *> * formalsListNode;
    LILC::FormalDeclNode * formalDeclNode;
    LILC::FnBodyNode * fnBodyNode;
    LILC::StmtNode * stmtNode;
    std::list<StmtNode *> * stmtListNode;

    LILC::ExpNode * expNode;
    std::list<ExpNode *> * expListNode;
    LILC::CallExpNode * callExpNode;
    LILC::UnaryExpNode * unaryExpNode;
    LILC::AssignNode * assignNode;

    LILC::DotAccessNode * dotAccessNode;

	/*LILC::Token * token;*/
}

%define parse.assert

%token               END    0     "end of file"
%token               NEWLINE "newline"
%token               CHAR
%token               BOOL
%token               INT
%token               VOID
%token               TRUE
%token               FALSE
%token               STRUCT
%token               INPUT
%token               OUTPUT
%token               IF
%token               ELSE
%token               WHILE
%token               RETURN
%token <idTokenValue> ID
%token <intTokenValue> INTLITERAL
%token <strTokenValue> STRINGLITERAL
%token               LCURLY
%token               RCURLY
%token               LPAREN
%token               RPAREN
%token               SEMICOLON
%token               COMMA
%token               DOT
%token               WRITE
%token               READ
%token               PLUSPLUS
%token               MINUSMINUS
%token               PLUS
%token               MINUS
%token               TIMES
%token               DIVIDE
%token               NOT
%token               AND
%token               OR
%token               EQUALS
%token               NOTEQUALS
%token               LESS
%token               GREATER
%token               LESSEQ
%token               GREATEREQ
%token               ASSIGN

/* Nonterminals
*  NOTE: You will need to add more nonterminals
*  to this list as you add productions to the grammar
*  below.
*/
%type <programNode> program
%type <declList> declList
%type <declNode> decl
%type <varDeclList> varDeclList
%type <varDeclNode> varDecl
%type <typeNode> type
%type <idNode> id
/*%type <intLitNode> intVal
%type <strLitNode> strVal*/
%type <structDeclNode> structDecl
%type <structBodyNode> structBody
%type <fnDeclNode> fnDecl
%type <formalsNode> formals
%type <formalsListNode> formalsList
%type <formalDeclNode> formalDecl
%type <fnBodyNode> fnBody
%type <stmtNode> stmt
%type <stmtListNode> stmtList

%type <expNode> exp
%type <expListNode> actualList
%type <callExpNode> fncall
%type <expNode> loc
%type <ExpNode> term
%type <assignNode> assignExp


/* NOTE: Make sure to add precedence and associativity
 * declarations
*/

%left ASSIGN
%right DOT
%left AND OR
%nonassoc EQUALS NOTEQUALS LESS LESSEQ GREATER GREATEREQ
%left PLUS MINUS
%left TIMES DIVIDE
%left UMINUS NOT

%%

program : declList {
    //$$ = new ProgramNode(new DeclListNode($1));
    $$ = new ProgramNode(new DeclListNode($1));
    compiler.setASTRoot($$);
};


declList : declList decl {
    $1->push_back($2);
	$$ = $1;
} | /* epsilon */ {
	$$ = new std::list<DeclNode *>();
};


decl : varDecl { $$ = $1; }
  | structDecl { $$ = $1; }
  | fnDecl { $$ = $1; };


varDeclList : varDeclList varDecl {
    $1->push_back($2);
	$$ = $1;
} | /* epsilon */ {
	$$ = new std::list<VarDeclNode *>();
};


varDecl : type id SEMICOLON {
    $$ = new VarDeclNode($1, $2, VarDeclNode::NOT_STRUCT);
} | STRUCT id id SEMICOLON {
    $$ = new VarDeclNode(new StructNode($2), $3, 0);
};


fnDecl: type id formals fnBody {
    $$ = new FnDeclNode($1, $2, $3, $4);
};


structDecl : STRUCT id LCURLY structBody RCURLY SEMICOLON {
    $$ = new StructDeclNode($2, $4);
};


structBody : structBody varDecl {
    $1->myVarDecls.push_back($2);
    $$ = $1;
} | varDecl {
    std::list<DeclNode*>* list = new std::list<DeclNode*>;
    list->push_back($1);
    $$ = list;
};


formals : LPAREN RPAREN {
  $$ = new std::list<FormalDeclNode*>();;
} | LPAREN formalsList RPAREN {
  $$ = $2;
};


formalsList : formalDecl {
    std::list<FormalDeclNode*>* list = new std::list<FormalDeclNode*>;
    list->push_back($1);
    $$ = list;
} | formalDecl COMMA formalsList {
    $3->push_front($1);
    $$ = $3;
};


formalDecl : type id {
  $$ = new FormalDeclNode($1, $2);
};


fnBody : LCURLY varDeclList stmtList RCURLY {
  $$ = new FnBodyNode(new DeclListNode($2), new StmtListNode($3));
};


stmtList : stmtList stmt {
    $1->push_back($2);
    $$ = $1;
} | /* epsilon */ {
  $$ = new std::list<StmtNode *>();
};


stmt : assignExp SEMICOLON {
  $$ = new AssignStmtNode($1);
} | loc PLUSPLUS SEMICOLON {
  $$ = new PostIncStmtNode($1);
} | loc MINUSMINUS SEMICOLON {
  $$ = new PostDecStmtNode($1);
} | INPUT READ loc SEMICOLON {
  $$ = new ReadStmtNode($3);
} | OUTPUT WRITE exp SEMICOLON {
  $$ = new WriteStmtNode($3);
} | IF LPAREN exp RPAREN LCURLY varDeclList stmtList RCURLY {
  $$ = new IfStmtNode($3, new DeclListNode($6), new StmtListNode($7));
} | IF LPAREN exp RPAREN LCURLY varDeclList stmtList RCURLY ELSE LCURLY varDeclList stmtList RCURLY {
  $$ = new IfElseStmtNode($3, new DeclListNode($6), new StmtListNode($7), new DeclListNode($11), new StmtListNode($12));
} | WHILE LPAREN exp RPAREN LCURLY varDeclList stmtList RCURLY {
  $$ = new WhileStmtNode($3, new DeclListNode($6), new StmtListNode($7));
} | RETURN exp SEMICOLON {
  $$ = new ReturnStmtNode($2);
} | RETURN SEMICOLON {
  $$ = new ReturnStmtNode(nullptr);
} | fncall SEMICOLON {
  $$ = new CallStmtNode($1);
};


exp : assignExp {
  $$ = $1;
} | exp PLUS exp {
  $$ = new PlusNode($1, $3);
} | exp MINUS exp {
  $$ = new MinusNode($1, $3);
} | exp TIMES exp {
  $$ = new TimesNode($1, $3);
} | exp DIVIDE exp {
  $$ = new DivideNode($1, $3);
} | NOT exp {
  $$ = new NotNode($2);
} | exp AND exp {
  $$ = new AndNode($1, $3);
} | exp OR exp {
  $$ = new OrNode($1, $3);
} | exp EQUALS exp {
  $$ = new EqualsNode($1, $3);
} | exp NOTEQUALS exp {
  $$ = new NotEqualsNode($1, $3);
} | exp LESS exp {
  $$ = new LessNode($1, $3);
} | exp GREATER exp {
  $$ = new GreaterNode($1, $3);
} | exp LESSEQ exp {
  $$ = new LessEqNode($1, $3);
} | exp GREATEREQ exp {
  $$ = new GreaterEqNode($1, $3);
} | MINUS term %prec UMINUS {
  $$ = new UnaryMinusNode($2);
} | term {
  $$ = $1;
};


assignExp : loc ASSIGN exp {
  $$ = new AssignNode($1, $3);
};


term : loc {
    $$ = $1;
} | INTLITERAL {
  $$ = new IntLitNode($1);
} | STRINGLITERAL {
  $$ = new StrLitNode($1);
} | TRUE {
  $$ = new TrueNode();
} | FALSE {
  $$ = new FalseNode();
} | LPAREN exp RPAREN {
  $$ = $2;
} | fncall {
  $$ = $1;
};


fncall : id LPAREN RPAREN {
  $$ = new CallExpNode($1, new ExpListNode(new std::list<ExpNode *>()));
} | id LPAREN actualList RPAREN {
  $$ = new CallExpNode($1, new ExpListNode($3));
};


actualList : exp {
  std::list<ExpNode*>* list = new std::list<ExpNode*>();
  list->push_back($1);
  $$ = $1;

} | actualList COMMA exp {
  $1->push_back($3);
  $$ = $1;

};



type : INT { $$ = new IntNode(); };
type : BOOL { $$ = new BoolNode(); };
type : VOID { $$ = new VoidNode(); };


loc : id {
  $$ = $1;
} | loc DOT id {
  $$ = new DotAccessNode($1, $3);
};


id : ID { $$ = new IdNode($1); };
%%
void
LILC::LilC_Parser::error(const std::string &err_message )
{
    std::cerr << "Error: " << err_message << "\n";
}
