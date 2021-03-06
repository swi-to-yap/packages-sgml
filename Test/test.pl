/*  Part of SWI-Prolog

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@cs.vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2000-2013, University of Amsterdam
			      VU University Amsterdam

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/

:- module(sgml_test,
	  [ test/1,			% +File
	    testdir/1,			% +Dir
	    pass/1,			% +File
	    show/1,			% +File
	    test/0
	  ]).

:- prolog_load_context(directory, CWD),
   working_directory(_, CWD).

:- asserta(user:file_search_path(library, '..')).
:- asserta(user:file_search_path(library, '../../RDF')).
:- asserta(user:file_search_path(foreign, '..')).
:- use_module(library(sgml)).
:- use_module(library(pretty_print)).
:- use_module(library(maplist)).
:- use_module(library(lists)).

:- dynamic failed/1.

test :-
	testdir(.).

testdir(Dir) :-
	retractall(failed(_)),
	atom_concat(Dir, '/*', Pattern),
	expand_file_name(Pattern, Files),
	maplist(dotest, Files),
	report_failed.

dotest(File) :-
	file_name_extension(_, Ext, File),
	memberchk(Ext, [sgml, xml, html]), !,
	test(File).
dotest(_).

test(File) :-
	debug(sgml(test), 'Test ~w ... ', [File]),
	flush_output,
	load_file(File, Term),
	ground(Term),			% make sure
	okfile(File, OkFile),
	(   exists_file(OkFile)
	->  load_prolog_file(OkFile, TermOk, ErrorsOk),
	    (	compare_dom(Term, TermOk)
	    ->	true
	    ;   assert(failed(File)),
	        format('WRONG'),
	        format('~NOK:~n'),
		pretty_print(TermOk),
		format('~NANSWER:~n'),
		pretty_print(Term)
	    ),
	    error_terms(Errors),
	    (	compare_errors(Errors, ErrorsOk)
	    ->	true
	    ;	retractall(failed(File)),
		assert(failed(File)),
		format(' [Different errors]~nOK:~n'),
		pretty_print(ErrorsOk),
		format('~NANSWER:~n'),
		pretty_print(Errors)
	    )
	;   show_errors,
	    format('Loaded, no validating data~n'),
	    pretty_print(Term)
	).

show(File) :-
	load_file(File, Term),
	pretty_print(Term).

pass(File) :-
	load_file(File, Term),
	okfile(File, OkFile),
	open(OkFile, write, Fd),
	format(Fd, '~q.~n', [Term]),
	(   error_terms(Errors)
	->  format(Fd, '~q.~n', [Errors])
	;   true
	),
	close(Fd).

report_failed :-
	findall(X, failed(X), L),
	length(L, Len),
	(   Len > 0
        ->  format('~N*** ~w tests failed ***~n', [Len]),
	    fail
        ;   format('~NAll tests passed~n', [])
	).

:- dynamic
	error/3.
:- multifile
	user:message_hook/3.

user:message_hook(Term, Kind, Lines) :-
	Term = sgml(_,_,_,_),
	assert(error(Term, Kind, Lines)).

show_errors :-
	(   error(_Term, Kind, Lines),
	    atom_concat(Kind, ': ', Prefix),
	    print_message_lines(user_error, Prefix, Lines),
	    fail
	;   true
	).

error_terms(Errors) :-
	findall(Term, error(Term, _, _), Errors).

compare_errors([], []).
compare_errors([sgml(_Parser1, _File1, Line, Msg)|T0],
	       [sgml(_Parser2, _File2, Line, Msg)|T]) :-
	compare_errors(T0, T).

load_file(File, Term) :-
	load_pred(Ext, Pred),
	file_name_extension(_, Ext, File), !,
	retractall(error(_,_,_)),
	call(Pred, File, Term).
load_file(Base, Term) :-
	load_pred(Ext, Pred),
	file_name_extension(Base, Ext, File),
	exists_file(File), !,
	retractall(error(_,_,_)),
	call(Pred, File, Term).


load_pred(sgml,	load_sgml_file).
load_pred(xml,	load_xml_file).
load_pred(html,	load_html_file).

okfile(File, OkFile) :-
	file_name_extension(Base, _, File),
	file_directory_name(Base, Dir),
	atomic_list_concat([Dir, '/ok/', Base, '.ok'], OkFile).

load_prolog_file(File, Term, Errors) :-
	open(File, read, Fd,
	     [ encoding(utf8)
	     ]),
	read(Fd, Term),
	(   read(Fd, Errors),
	    Errors \== end_of_file
	->  true
	;   Errors = []
	),
	close(Fd).

compare_dom([], []) :- !.
compare_dom([H1|T1], [H2|T2]) :- !,
	compare_dom(H1, H2),
	compare_dom(T1, T2).
compare_dom(X, X) :- !.
compare_dom(element(Name, A1, Content1),
	    element(Name, A2, Content2)) :-
	compare_attributes(A1, A2),
	compare_dom(Content1, Content2).

compare_attributes(A1, A2) :-
	sort(A1, L1),
	sort(A2, L2),
	L1 == L2.



