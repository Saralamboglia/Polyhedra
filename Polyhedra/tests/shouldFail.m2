-- coneFromVData fails with wrong number of rows
TEST /// 
R = matrix {{1,0},{0,1}};
L = matrix {{}};
assert((try coneFromVData(R, L) else oops) === oops)
assert((try coneFromVData(L, R) else oops) === oops)
///

-- convexHull fails with wrong number of rows
TEST /// 
R = matrix {{1,0},{0,1}};
L = matrix {{}};
assert((try convexHull(R, L) else oops) === oops)
assert((try convexHull(L, R) else oops) === oops)
///

-- fan fails with wrong number of rows
TEST /// 
R = matrix {{1,0},{0,1}};
L = matrix {{}};
MC = {{}};
assert((try fan(R, L, MC) else oops) === oops)
assert((try fan(L, R, MC) else oops) === oops)
///

-- intersection fails with wrong number of columns
TEST /// 
R = matrix {{1,0},{0,1}};
L = matrix {{}};
assert((try intersection(R, L) else oops) === oops)
assert((try intersection(L, R) else oops) === oops)
///

-- fan constructors
TEST ///
RAYS = transpose matrix {{1,0,0},{0,1,0}};
CONES = {{}, {0}, {1}};
CONES1 = {{0},{1}};
assert((try fan(RAYS|RAYS, {{}}) else oops) === oops)
assert((try fan(RAYS, CONES) else oops) === oops)
assert((try fan(RAYS, CONES1) else oops) =!= oops)
///
