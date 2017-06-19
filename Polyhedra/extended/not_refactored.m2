-- The following contains methods that have only been partially refactored because:
-- * They were too long.
-- * We did not know what they do or
-- * We did not know how they work.
-- * We had no way of testing them at this point.
-- These methods have been fixed to work with the new setup. Use at own risk.


-- PURPOSE : Computing the state polytope of the ideal 'I'
--   INPUT : 'I',  a homogeneous ideal with resect to some strictly psoitive grading
--  OUTPUT : The state polytope as a polyhedron
statePolytope = method(TypicalValue => Polyhedron)
statePolytope Ideal := I -> (
   -- Check if there exists a strictly positive grading such that 'I' is homogeneous with
   -- respect to this grading
   homogeneityCheck := I -> (
      -- Generate the matrix 'M' that spans the space of the differeneces of the 
      -- exponent vectors of the generators of 'I'
      L := flatten entries gens I;
      lt := apply(L, leadTerm);
      M := matrix flatten apply(#L, i -> apply(exponents L#i, e -> (flatten exponents lt#i)-e));
      -- intersect the span of 'M' with the positive orthant
      C := intersection(map(source M,source M,1),M);
      -- Check if an interior vector is strictly positive
      v := interiorVector C;
      (all(flatten entries v, e -> e > 0),v)
   );
   -- Compute the Groebner cone
   gCone := (g,lt) -> (
      -- for a given groebner basis compute the reduced Groebner basis
      -- note: might be obsolete, but until now (Jan2009) groebner bases appear to be not reduced
      g = apply(flatten entries gens g, l -> ((l-leadTerm(l))% g)+leadTerm(l));
      -- collect the differences of the exponent vectors of the groebner basis
      lt = flatten entries lt;
      L := matrix flatten apply(#g, i -> apply(exponents g#i, e -> (flatten exponents lt#i)-e));
      -- intersect the differences
      intersection L
   );
   wLeadTerm := (w,I) -> (
      -- Compute the Groebner basis and their leading terms of 'I' with respect to the weight 'w'
      R := ring I;
      -- Resize w to a primitive vector in ZZ
      w = flatten entries substitute((1 / abs gcd flatten entries w) * w,ZZ);
      -- generate the new ring with weight 'w'
      S := (coefficientRing R)[gens R, MonomialOrder => {Weights => w}, Global => false];
      f := map(S,R);
      -- map 'I' into 'S' and compute Groebner basis and leadterm
      I1 := f I;
      g := gb I1;
      lt := leadTerm I1;
      gbRemove I1;
      (g,lt)
   );
   makePositive := (w,posv) -> (
      w = flatten entries w;
      posv = flatten entries posv;
      j := min(apply(#w, i -> w#i/posv#i));
      if j <= 0 then j = 1 - floor j else j = 0;
      matrix transpose{w + j * posv}
   );
   -- computes the symmetric difference of the two lists
   sortIn := (L1,L2) -> ((a,b) := (set apply(L1,first),set apply(L2,first)); join(select(L1,i->not b#?(i#0)),select(L2,i->not a#?(i#0))));
   --Checking for homogeneity
   (noError,posv) := homogeneityCheck I;
   if not noError then error("The ideal must be homogeneous w.r.t. some strictly positive grading");
   -- Compute a first Groebner basis to start with
   g := gb I;
   lt := leadTerm I;
   -- Compute the Groebner cone
   C := gCone(g,lt);
   gbRemove I;
   -- Generate all facets of 'C'
   -- Save each facet by an interior vector of it, the facet itself and the cone from 
   -- which it has been computed
   raysC := rays C;
   triplets := C -> (
      raysC := rays C;
      linC := linealitySpace C;
      apply(faces(1,C), 
         f -> (
            fCone := coneFromVData(raysC_f, linealitySpace C);
            (interiorVector fCone,fCone,C)
         )
      )
   );
   facets := triplets C;
   --Save the leading terms as the first vertex
   verts := {lt};
   -- Scan the facets
   while facets != {} do (
      local omega';
      local f;
      (omega',f,C) = facets#0;
      -- compute an interior vector of the big cone 'C' and take a small 'eps'
      omega := promote(interiorVector C,QQ);
      eps := 1/10;
      omega1 := omega'-(eps*omega);
      (g,lt) = wLeadTerm(makePositive(omega1,posv),I);
      C' := gCone(g,lt);
      -- reduce 'eps' until the Groebner cone generated by omega'-(eps*omega) is 
      -- adjacent to the big cone 'C'
      while intersection(C,C') != f do (
          eps = eps * 1/10;
          omega1 = omega'-(eps*omega);
          (g,lt) = wLeadTerm(makePositive(omega1,posv),I);
          C' = gCone(g,lt)
      );
      C = C';
      -- save the new leadterms as a new vertex
      verts = append(verts,lt);
      -- Compute the facets of the new Groebner cone and save them in the same way as before
      newfacets := triplets C;
      -- Save the symmetric difference into 'facets'
      facets = sortIn(facets,newfacets)
   );
   posv = substitute(posv,ZZ);
   R := ring I;
   -- generate a new ring with the strictly positive grading computed by the homogeneity check
   S := QQ[gens R, Degrees => entries posv];
   -- map the vertices into the new ring 'S'
   verts = apply(verts, el -> (map(S,ring el)) el);
   -- Compute the maximal degree of the vertices
   L := flatten apply(verts, l -> flatten entries l);
   d := (max apply(flatten L, degree))#0;
   -- compute the vertices of the state polytope
   vertmatrix := transpose matrix apply(verts, v -> (
       VI := ideal flatten entries v;
       SI := S/VI;
       v = flatten apply(d, i -> flatten entries basis(i+1,SI));
       flatten sum apply(v,exponents))
   );
   -- Compute the state polytope
   P := convexHull vertmatrix;
   (verts,P)
);


-- PURPOSE : Computing the closest point of a polyhedron to a given point
--   INPUT : (p,P),  where 'p' is a point given by a one column matrix over ZZ or QQ and
--                   'P' is a Polyhedron
--  OUTPUT : the point in 'P' with the minimal euclidian distance to 'p'
proximum = method(TypicalValue => Matrix)
proximum (Matrix,Polyhedron) := (p,P) -> (
     -- Checking for input errors
     if numColumns p =!= 1 or numRows p =!= ambDim(P) then error("The point must lie in the same space");
     if isEmpty P then error("The polyhedron must not be empty");
     -- Defining local variables
     local Flist;
     d := ambDim P;
     c := 0;
     prox := {};
     -- Checking if 'p' is contained in 'P'
     if contains(P,p) then p
     else (
	  V := vertices P;
	  R := promote(rays P,QQ);
	  -- Distinguish between full dimensional polyhedra and not full dimensional ones
	  if dim P == d then (
	       -- Continue as long as the proximum has not been found
	       while instance(prox,List) do (
		    -- Take the faces of next lower dimension of P
		    c = c+1;
		    if c == dim P then (
			 Vdist := apply(numColumns V, j -> ((transpose(V_{j}-p))*(V_{j}-p))_(0,0));
			 pos := min Vdist;
			 pos = position(Vdist, j -> j == pos);
			 prox = V_{pos})
		    else (
			 Flist = faces(c,P);
			 -- Search through the faces
			 any(Flist, (v, r) -> (
               F := convexHull((vertices P)_v, (rays P)_r, linealitySpace P);
				   -- Take the inward pointing normal cone with respect to P
				   (vL,bL) := hyperplanes F;
				   -- Check for each ray if it is pointing inward
				   vL = matrix apply(numRows vL, i -> (
					     v := vL^{i};
					     b := first flatten entries bL^{i};
					     if all(flatten entries (v*(V | R)), e -> e >= b) then flatten entries v
					     else flatten entries(-v)));
				   -- Take the polyhedron spanned by the inward pointing normal cone 
				   -- and 'p' and intersect it with the face
				   Q := intersection(F,convexHull(p,transpose vL));
				   -- If this intersection is not empty, it contains exactly one point, 
				   -- the proximum
				   if not isEmpty Q then (
					prox = vertices Q;
					true)
				   else false))));
	       prox)
	  else (
	       -- For not full dimensional polyhedra the hyperplanes of 'P' have to be considered also
	       while instance(prox,List) do (
		    if c == dim P then (
			 Vdist1 := apply(numColumns V, j -> ((transpose(V_{j}-p))*(V_{j}-p))_(0,0));
			 pos1 := min Vdist1;
			 pos1 = position(Vdist1, j -> j == pos1);
			 prox = V_{pos1})
		    else (
			 Flist = faces(c,P);
			 -- Search through the faces
			 any(Flist, (v, r) -> (
               F := convexHull((vertices P)_v, (rays P)_r, linealitySpace P);
				   -- Take the inward pointing normal cone with respect to P
				   (vL,bL) := hyperplanes F;
				   vL = matrix apply(numRows vL, i -> (
					     v := vL^{i};
					     b := first flatten entries bL^{i};
					     entryList := flatten entries (v*(V | R));
					     -- the first two ifs find the vectors not in the hyperspace
					     -- of 'P'
					     if any(entryList, e -> e > b) then flatten entries v
					     else if any(entryList, e -> e < b) then flatten entries(-v)
					     -- If it is an original hyperplane than take the direction from 
					     -- 'p' to the polyhedron
					     else (
						  bCheck := first flatten entries (v*p);
						  if bCheck < b then flatten entries v
						  else flatten entries(-v))));
				   Q := intersection(F,convexHull(p,transpose vL));
				   if not isEmpty Q then (
					prox = vertices Q;
					true)
				   else false)));
		    c = c+1);
	       prox)))


--   INPUT : (p,C),  where 'p' is a point given by a one column matrix over ZZ or QQ and
--                   'C' is a Cone
--  OUTPUT : the point in 'C' with the minimal euclidian distance to 'p'
proximum (Matrix,Cone) := (p,C) -> proximum(p,polyhedron C)



-- PURPOSE : Tests if a Fan is projective
--   INPUT : 'F'  a Fan
--  OUTPUT : a Polyhedron, which has 'F' as normal fan, if 'F' is projective or the empty polyhedron
compute#Fan#polytopal = method(TypicalValue => Boolean)
compute#Fan#polytopal Fan := F -> (
   -- First of all the fan must be complete
   if isComplete F then (
      -- Extracting the generating cones, the ambient dimension, the codim 1 
      -- cones (corresponding to the edges of the polytope if it exists)
      i := 0;
      L := hashTable apply(getProperty(F, honestMaxObjects), l -> (i=i+1; i=>l));
      n := ambDim(F);
      edges := cones(n-1,F);
      raysF := rays F;
      linF := linealitySpace F;
      edges = apply(edges, e -> coneFromVData(raysF_e, linF));
      -- Making a table that indicates in which generating cones each 'edge' is contained
      edgeTCTable := hashTable apply(edges, e -> select(1..#L, j -> contains(L#j,e)) => e);
      i = 0;
      -- Making a table of all the edges where each entry consists of the pair of top cones corr. to
      -- this edge, the codim 1 cone, an index number i, and the edge direction from the first to the
      -- second top Cone
      edgeTable := apply(pairs edgeTCTable, 
         e -> (i=i+1; 
            v := transpose hyperplanes e#1;
            if not contains(dualCone L#((e#0)#0),v) then v = -v;
            (e#0, e#1, i, v)
         )
      );
      edgeTCNoTable := hashTable apply(edgeTable, e -> e#0 => (e#2,e#3));
      edgeTable = hashTable apply(edgeTable, e -> e#1 => (e#2,e#3));
      -- Computing the list of correspondencies, i.e. for each codim 2 cone ( corresponding to 2dim-faces of the polytope) save 
      -- the indeces of the top cones containing it
      corrList := hashTable {};
      scan(keys L, 
         j -> (
            raysL := rays L#j;
            linL := linealitySpace L#j;
            corrList = merge(corrList,hashTable apply(faces(2,L#j), C -> (raysL_C, linL) => {j}),join)
         )
      );
      corrList = pairs corrList;
      --  Generating the 0 matrix for collecting the conditions on the edges
      m := #(keys edgeTable);
      -- for each entry of corrlist another matrix is added to hyperplanesTmp
      hyperplanesTmp := flatten apply(#corrList, 
         j -> (
            v := corrList#j#1;
            hyperplanesTmpnew := map(ZZ^n,ZZ^m,0);
            -- Scanning trough the top cones containing the active codim2 cone and order them in a circle by their 
            -- connecting edges
            v = apply(v, e -> L#e);
            C := v#0;
            v = drop(v,1);
            C1 := C;
            nv := #v;
            scan(nv, 
               i -> (
                  i = position(v, e -> dim intersection(C1,e) == n-1);
                  C2 := v#i;
                  v = drop(v,{i,i});
                  abpos := position(keys edgeTable, k -> k == intersection(C1,C2));
                  abkey := (keys edgeTable)#abpos;
                  (a,b) := edgeTable#abkey;
                  if not contains(dualCone C2,b) then b = -b;
                  -- 'b' is the edge direction inserted in column 'a', the index of this edge
                  hyperplanesTmpnew = hyperplanesTmpnew_{0..a-2} | b | hyperplanesTmpnew_{a..m-1};
                  C1 = C2
               )
            );
            C3 := intersection(C,C1);
            abpos := position(keys edgeTable, k -> k == C3);
            abkey := (keys edgeTable)#abpos;
            (a,b) := edgeTable#abkey;
            if not contains(dualCone C,b) then b = -b;
            -- 'b' is the edge direction inserted in column 'a', the index of this edge
            -- the new restriction is that the edges ''around'' this codim2 Cone must add up to 0
            entries(hyperplanesTmpnew_{0..a-2} | b | hyperplanesTmpnew_{a..m-1})
         )
      );
      if hyperplanesTmp != {} then hyperplanesTmp = matrix hyperplanesTmp
      else hyperplanesTmp = map(ZZ^0,ZZ^m,0);
      -- Find an interior vector in the cone of all positive vectors satisfying the restrictions
      v := flatten entries interiorVector intersection(id_(ZZ^m),hyperplanesTmp);
      M := {};
      -- If the vector is strictly positive then there is a polytope with 'F' as normalFan
      if all(v, e -> e > 0) then (
         -- Construct the polytope
         i = 1;
         -- Start with the origin
         p := map(ZZ^n,ZZ^1,0);
         M = {p};
         Lyes := {};
         Lno := {};
         vlist := apply(keys edgeTCTable,toList);
         -- Walk along all edges recursively
         edgerecursion := (i,p,vertexlist,Mvertices) -> (
            vLyes := {};
            vLno := {};
            -- Sorting those edges into 'vLyes' who emerge from vertex 'i' and the rest in 'vLno'
            vertexlist = partition(w -> member(i,w),vertexlist);
            if vertexlist#?true then vLyes = vertexlist#true;
            if vertexlist#?false then vLno = vertexlist#false;
            -- Going along the edges in 'vLyes' with the length given in 'v' and calling edgerecursion again with the new index of the new 
            -- top Cone, the new computed vertex, the remaining edges in 'vLno' and the extended matrix of vertices
            scan(vLyes, 
               w -> (
                  w = toSequence w;
                  j := edgeTCNoTable#w;
                  if w#0 == i then (
                     (vLno,Mvertices) = edgerecursion(w#1,p+(j#1)*(v#((j#0)-1)),vLno,append(Mvertices,p+(j#1)*(v#((j#0)-1))))
                  )
                  else (
                     (vLno,Mvertices) = edgerecursion(w#0,p-(j#1)*(v#((j#0)-1)),vLno,append(Mvertices,p-(j#1)*(v#((j#0)-1))))
                  )
               )
            );
            (vLno,Mvertices)
         );
         -- Start the recursion with vertex '1', the origin, all edges and the vertexmatrix containing already the origin
         M = unique ((edgerecursion(i,p,vlist,M))#1);
         M = matrix transpose apply(M, m -> flatten entries m);
         -- Computing the convex hull
         setProperty(F, computedPolytope, convexHull M);
         return true
      )
   );
   return false
)


compute#Fan#computedPolytope = method()
compute#Fan#computedPolytope Fan := F -> (
   if not isPolytopal F then error("Fan is not polytopal")
   else polytope F
)


-- PURPOSE : Computes the mixed volume of n polytopes in n-space
--   INPUT : 'L'  a list of n polytopes in n-space
--  OUTPUT : the mixed volume
-- COMMENT : Note that at the moment the input is NOT checked!
--           The name of this algorithm is the "Lift-Prune algorithm"
mixedVolume = method()
mixedVolume List := L -> (
   n := #L;
   if not all(L, isCompact) then error("Polyhedra must be compact.");
   EdgeList := apply(L, 
      P -> (
         vertP := vertices P;
         apply(faces(dim P -1,P), f -> vertP_(f#0))
      )
   );
   liftings := apply(n, i -> map(ZZ^n,ZZ^n,1)||matrix{apply(n, j -> random 25)});
   Qlist := apply(n, i -> affineImage(liftings#i,L#i));
   local Qsum;
   Qsums := apply(n, i -> if i == 0 then Qsum = Qlist#0 else Qsum = Qsum + Qlist#i);
   mV := 0;
   EdgeList = apply(n, i -> apply(EdgeList#i, e -> (e,(liftings#i)*e)));
   E1 := EdgeList#0;
   EdgeList = drop(EdgeList,1);
   center := matrix{{1/2},{1/2}};
   edgeTuple := {};
   k := 0;
   selectRecursion := (currentEdges,edgeTuple,EdgeList,mV,Qsums,Qlist,k) -> (
      if k > n then << "Alarm!!! Forgot to do something." << endl;
      for e1 in currentEdges do (
         Elocal := EdgeList;
         if Elocal == {} then (
            mV = mV + (volume sum apply(edgeTuple|{e1}, et -> convexHull first et))
         )
         else (
            Elocal = for i from 0 to #Elocal-1 list (
               P := Qsums#k + Qlist#(k+i+1);
               hyperplanesTmp := getLowerEnvelopeHyperplanes P;
               returnE := select(Elocal#i, 
                  e -> (
                     p := (sum apply(edgeTuple|{e1}, et -> et#1 * center)) + (e#1 * center);
                     any(hyperplanesTmp, pair -> (pair#0)*p - pair#1 == 0)
                  )
               );
               --if returnE == {} then break{};
               returnE
            );
            mV = selectRecursion(Elocal#0,edgeTuple|{e1},drop(Elocal,1),mV,Qsums,Qlist,k+1)
         )
      );
      mV
   );
   selectRecursion(E1,edgeTuple,EdgeList,mV,Qsums,Qlist,k)
)

getLowerEnvelopeHyperplanes = method();
getLowerEnvelopeHyperplanes Polyhedron := P -> (
   n := ambDim P - 1;
   F := facets P;
   H := hyperplanes P;
   FH := (F#0 || H#0 || -H#0, F#1 || H#1 || -H#1);
   result := for j from 0 to numRows(FH#0)-1 list 
      if (FH#0)_(j,n) < 0 then ((FH#0)^{j},(FH#1)^{j}) 
      else continue;
   result
)


Cone ? Cone := (C1,C2) -> (
    if C1 == C2 then symbol == else (
	if ambDim C1 != ambDim C2 then ambDim C1 ? ambDim C2 else (
	    if dim C1 != dim C2 then dim C1 ? dim C2 else (
		R1 := rays C1;
		R2 := rays C2;
		if R1 != R2 then (
		    R1 = apply(numColumns R1, i -> R1_{i});
		    R2 = apply(numColumns R2, i -> R2_{i});
		    (a,b) := (set R1,set R2); 
		    r := (sort matrix {join(select(R1,i->not b#?i),select(R2,i->not a#?i))})_{0};
		    if a#?r then symbol > else symbol <)
		else (
		    R1 = linSpace C1;
		    R2 = linSpace C2;
		    R1 = apply(numColumns R1, i -> R1_{i});
		    R2 = apply(numColumns R2, i -> R2_{i});
		    (c,d) := (set R1,set R2);
		    l := (sort matrix {join(select(R1,i->not d#?i),select(R2,i->not c#?i))})_{0};
		    if c#?l then symbol > else symbol <)))))


-- PURPOSE : Computing the Cone of the Minkowskisummands of a Polyhedron 'P', the minimal 
--           Minkowskisummands, and minimal decompositions
--   INPUT : 'P',  a polyhedron
--  OUTPUT : '(C,L,M)'  where 'C' is the Cone of the Minkowskisummands, 'L' is a list of 
--                      Polyhedra corresponding to the generators of 'C', and 'M' is a 
--                      matrix where the columns give the minimal decompositions of 'P'.
minkSummandCone = method()
minkSummandCone Polyhedron := P -> (
     -- Subfunction to save the two vertices of a compact edge in a matrix where the vertex with the smaller entries comes first
     -- by comparing the two vertices entry-wise
     normvert := M -> ( 
	  M = toList M; 
	  v := (M#0)-(M#1);
	  normrec := w -> if (entries w)#0#0 > 0 then 0 else if (entries w)#0#0 < 0 then 1 else (w = w^{1..(numRows w)-1}; normrec w);
          i := normrec v;
	  if i == 1 then M = {M#1,M#0};
	  M);
     -- If the polyhedron is 0 or 1 dimensional itself is its only summand
     if dim P == 0 or dim P == 1 then (coneFromVData matrix{{1}}, hashTable {0 => P},matrix{{1}})
     else (
	  -- Extracting the data to compute the 2 dimensional faces and the edges
	  d := ambDim(P);
          dP := dim P;
          (HS,v) := halfspaces P;
          (hyperplanesTmp,w) := hyperplanes P;
	  F := apply(numRows HS, i -> polyhedronFromHData(HS,v,hyperplanesTmp || HS^{i},w || v^{i}));
	  F = apply(F, f -> (
		    V := vertices f;
		    R := rays f;
		    (set apply(numColumns V, i -> V_{i}),set apply(numColumns R, i -> R_{i}))));
	  LS := linSpace P;
	  L := F;
	  i := 1;
	  while i < dP-2 do (
	       L = intersectionWithFacets(L,F);
	       i = i+1);
	  -- Collect the compact edges
	  L1 := select(L, l -> l#1 === set{});
	  -- if the polyhedron is 2 dimensional and not compact then every compact edge with the tailcone is a summand
	  if dim P == 2 and (not isCompact P) then (
	       L1 = intersectionWithFacets(L,F);
	       L1 = select(L, l -> l#1 === set{});
	       if #L1 == 0 or #L1 == 1 then (coneFromVData matrix{{1}},hashTable {0 => P},matrix{{1}})
	       else (
		    TailC := rays P;
		    if linSpace P != 0 then TailC = TailC | linSpace P | -linSpace(P);
		    (coneFromVData map(QQ^(#L1),QQ^(#L1),1),hashTable apply(#L1, i -> i => convexHull((L1#i)#0 | (L1#i)#1,TailC)),matrix toList(#L1:{1_QQ}))))
	  else (
	       -- If the polyhedron is compact and 2 dimensional then there is only one 2 faces
	       if dim P == 2 then L1 = {(set apply(numColumns vertices P, i -> (vertices P)_{i}), set {})};
	       edges := {};
	       edgesTable := edges;
	       condmatrix := map(QQ^0,QQ^0,0);
	       scan(L1, l -> (
			 -- for every 2 face we get a couple of rows in the condition matrix for the edges of this 2 face
			 -- for this the edges if set in a cyclic order must add up to 0. These conditions are added to 
			 -- 'condmatrix' by using the indices in edges
			 ledges := apply(intersectionWithFacets({l},F), e -> normvert e#0);
			 -- adding e to edges if not yet a member
			 newedges := select(ledges, e -> not member(e,edges));
			 -- extending the condmatrix by a column of zeros for the new edge
			 condmatrix = condmatrix | map(target condmatrix,QQ^(#newedges),0);
			 edges = edges | newedges;
			 -- Bring the edges into cyclic order
			 oedges := {(ledges#0,1)};
			 v := ledges#0#1;
			 ledges = drop(ledges,1);
			 nledges := #ledges;
			 oedges = oedges | apply(nledges, i -> (
				   i = position(ledges, e -> e#0 == v or e#1 == v);
				   e := ledges#i;
				   ledges = drop(ledges,{i,i});
				   if e#0 == v then (
					v = e#1;
					(e,1))
				   else (
					v = e#0;
					(e,-1))));
			 M := map(QQ^d,source condmatrix,0);
			 -- for the cyclic order in oedges add the corresponding edgedirections to condmatrix
			 scan(oedges, e -> (
				   ve := (e#0#1 - e#0#0)*(e#1);
				   j := position(edges, edge -> edge == e#0);
				   M = M_{0..j-1} | ve | M_{j+1..(numColumns M)-1}));
			 condmatrix = condmatrix || M));
	       -- if there are no conditions then the polyhedron has no compact 2 faces
	       if condmatrix == map(QQ^0,QQ^0,0) then (
		    -- collect the compact edges
		    LL := select(faces(dim P - 1,P), fLL -> isCompact fLL);
		    -- if there is only none or one compact edge then the only summand is the polyhedron itself
		    if #LL == 0 or #LL == 1 then (coneFromVData matrix{{1}}, hashTable {0 => P},matrix{{1}})
		    -- otherwise we get a summand for each compact edge
		    else (
			 TailCLL := rays P;
			 if linSpace P != 0 then TailCLL = TailCLL | linSpace P | -linSpace(P);
			 (coneFromVData map(QQ^(#LL),QQ^(#LL),1),hashTable apply(#LL, i -> i => convexHull(vertices LL#i,TailCLL)),matrix toList(#LL:{1_QQ}))))
	       -- Otherwise we can compute the Minkowski summand cone
	       else (
		    Id := map(source condmatrix,source condmatrix,1);
		    C := coneFromHData(Id,condmatrix);
		    R := rays C;
		    TC := map(ZZ^(ambDim(P)),ZZ^1,0) | rays(P) | linSpace(P) | -(linSpace(P));
		    v = (vertices P)_{0};
		    -- computing the actual summands
		    summList := hashTable apply(numColumns R, i -> (
			      remedges := edges;
			      -- recursive function which takes 'L' the already computed vertices of the summandpolyhedron,
			      -- the set of remaining edges, the current vertex of the original polyhedron, the current 
			      -- vertex of the summandpolyhedron, and the ray of the minkSummandCone. It computes the
			      -- edges emanating from the vertex, scales these edges by the corresponding factor in mi, 
			      -- computes the vertices at the end of those edges (for the original and for the 
			      -- summandpolyhedron) and calls itself with each of the new vertices, if there are edges 
			      -- left in the list
			      edgesearch := (v,v0,mi) -> (
				   remedges = partition(e -> member(v,e),remedges);
				   Lnew := {};
				   if remedges#?true then Lnew = apply(remedges#true, e -> (
					     j := position(edges, edge -> edge == e);
					     edir := e#0 + e#1 - 2*v;
					     vnew := v0 + (mi_(j,0))*edir;
					     (v+edir,vnew,vnew != v0)));
				   if remedges#?false then remedges = remedges#false else remedges = {};
				   L := apply(select(Lnew, e -> e#2),e -> e#1);
				   Lnew = apply(Lnew, e -> (e#0,e#1));
				   L = L | apply(Lnew, (u,w) -> if remedges =!= {} then edgesearch(u,w,mi) else {});
				   flatten L);
			      mi := R_{i};
			      v0 := map(QQ^d,QQ^1,0);
			      -- Calling the edgesearch function to get the vertices of the summand
			      L := {v0} | edgesearch(v,v0,mi);
			      L = matrix transpose apply(L, e -> flatten entries e);
			      i => convexHull(L,TC)));
		    -- computing the inclusion minimal decompositions
		     onevec := matrix toList(numRows R: {1_QQ});
		     negId := map(source R,source R,-1);
		     zerovec :=  map(source R,ZZ^1,0);
		     Q := polyhedronFromHData(negId,zerovec,R,onevec);
		     (C,summList,vertices(Q))))))
