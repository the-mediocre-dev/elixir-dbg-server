-module(eds_utils).

-export([make_func/2, make_named_func/2]).

make_func(Arity, EvalFunc) ->
    case Arity of
	    0 -> {ok, fun () -> EvalFunc([]) end};
	    1 -> {ok, fun (A) -> EvalFunc([A]) end};
	    2 -> {ok, fun (A,B) -> EvalFunc([A,B]) end};
	    3 -> {ok, fun (A,B,C) -> EvalFunc([A,B,C]) end};
	    4 -> {ok, fun (A,B,C,D) -> EvalFunc([A,B,C,D]) end};
	    5 -> {ok, fun (A,B,C,D,E) -> EvalFunc([A,B,C,D,E]) end};
	    6 -> {ok, fun (A,B,C,D,E,F) -> EvalFunc([A,B,C,D,E,F]) end};
	    7 -> {ok, fun (A,B,C,D,E,F,G) -> EvalFunc([A,B,C,D,E,F,G]) end};
	    8 -> {ok, fun (A,B,C,D,E,F,G,H) -> EvalFunc([A,B,C,D,E,F,G,H]) end};
	    9 -> {ok, fun (A,B,C,D,E,F,G,H,I) -> EvalFunc([A,B,C,D,E,F,G,H,I]) end};
	    10 -> {ok, fun (A,B,C,D,E,F,G,H,I,J) -> EvalFunc([A,B,C,D,E,F,G,H,I,J]) end};
	    11 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K]) end};
	    12 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K,L) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L]) end};
	    13 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K,L,M) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M]) end};
	    14 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K,L,M,N) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N]) end};
	    15 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O]) end};
	    16 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P]) end};
	    17 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q]) end};
	    18 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R]) end};
	    19 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q, R,S]) end};
	    20 -> {ok, fun (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q, R,S,T]) end};
	    _Other -> {error, argument_limit}
	end.

make_named_func(Arity, EvalFunc) ->
    case Arity of
	    0 -> {ok, fun RF() -> EvalFunc([],RF) end};
	    1 -> {ok, fun RF(A) -> EvalFunc([A],RF) end};
	    2 -> {ok, fun RF(A,B) -> EvalFunc([A,B],RF) end};
	    3 -> {ok, fun RF(A,B,C) -> EvalFunc([A,B,C],RF) end};
	    4 -> {ok, fun RF(A,B,C,D) -> EvalFunc([A,B,C,D],RF) end};
	    5 -> {ok, fun RF(A,B,C,D,E) -> EvalFunc([A,B,C,D,E],RF) end};
	    6 -> {ok, fun RF(A,B,C,D,E,F) -> EvalFunc([A,B,C,D,E,F],RF) end};
	    7 -> {ok, fun RF(A,B,C,D,E,F,G) -> EvalFunc([A,B,C,D,E,F,G],RF) end};
	    8 -> {ok, fun RF(A,B,C,D,E,F,G,H) -> EvalFunc([A,B,C,D,E,F,G,H],RF) end};
	    9 -> {ok, fun RF(A,B,C,D,E,F,G,H,I) -> EvalFunc([A,B,C,D,E,F,G,H,I],RF) end};
	    10 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J) -> EvalFunc([A,B,C,D,E,F,G,H,I,J],RF) end};
	    11 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K],RF) end};
	    12 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K,L) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L],RF) end};
	    13 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K,L,M) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M],RF) end};
	    14 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K,L,M,N) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N],RF) end};
	    15 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K,L,M,N,O) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O],RF) end};
	    16 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P],RF) end};
	    17 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q],RF) end};
	    18 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R],RF) end};
	    19 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q, R,S],RF) end};
	    20 -> {ok, fun RF(A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T) -> EvalFunc([A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q, R,S,T],RF) end};
	    _Other -> {error, argument_limit}
	end.
