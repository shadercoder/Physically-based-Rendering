/**
 * Get a random value.
 * @param  {const float4} scale
 * @param  {const float}  seed  Seed for the random number.
 * @return {float}              A random number.
 */
inline float random( const float4 scale, const float seed ) {
	float i;
	return fract( native_sin( dot( seed, scale ) ) * 43758.5453f + seed, &i );
}


/**
 * http://www.rorydriscoll.com/2009/01/07/better-sampling/ (Not 1:1 used here.)
 * @param  {const float}  seed
 * @param  {const float4} normal
 * @return {float4}
 */
inline float4 cosineWeightedDirection( const float seed, const float4 normal ) {
	const float u = random( (float4)( 12.9898f, 78.233f, 151.7182f, 0.0f ), seed );
	const float v = random( (float4)( 63.7264f, 10.873f, 623.6736f, 0.0f ), seed );
	const float r = native_sqrt( u );
	const float angle = PI_X2 * v;

	// compute basis from normal
	const float4 tmp = ( fabs( normal.x ) < 0.5f )
	                 ? (float4)( 1.0f, 0.0f, 0.0f, 0.0f )
	                 : (float4)( 0.0f, 1.0f, 0.0f, 0.0f );
	const float4 sdir = cross( normal, tmp );
	const float4 tdir = cross( normal, sdir );

	return r * native_cos( angle ) * sdir + r * native_sin( angle ) * tdir + native_sqrt( 1.0f - u ) * normal;
}


/**
 * Get a vector in a random direction.
 * @param  {const float}  seed Seed for the random value.
 * @return {float4}            Random vector.
 */
inline float4 uniformlyRandomDirection( const float seed ) {
	const float v = random( (float4)( 12.9898f, 78.233f, 151.7182f, 0.0f ), seed );
	const float u = random( (float4)( 63.7264f, 10.873f, 623.6736f, 0.0f ), seed );
	const float z = 1.0f - 2.0f * u;
	const float r = native_sqrt( 1.0f - z * z );
	const float angle = PI_X2 * v;

	return (float4)( r * native_cos( angle ), r * native_sin( angle ), z, 0.0f );
}


/**
 * Get a vector in a random direction.
 * @param  {const float}  seed Seed for the random value.
 * @return {float4}            Random vector.
 */
inline float4 uniformlyRandomVector( const float seed ) {
	const float rnd = random( (float4)( 36.7539f, 50.3658f, 306.2759f, 0.0f ), seed );

	return uniformlyRandomDirection( seed ) * native_sqrt( rnd );
}


/**
 * Source: http://graphics.cg.uni-saarland.de/fileadmin/cguds/courses/ws0910/cg/rc/web_sites/Ziesche/
 * Which is based on: "An Efficient and Robust Ray–Box Intersection Algorithm", Williams et al.
 * @param  {const float4*} origin
 * @param  {const float4*} dir
 * @param  {const float*}  bbMin
 * @param  {const float*}  bbMax
 * @param  {float*}        tNear
 * @param  {float*}        tFar
 * @return {bool}
 */
bool intersectBoundingBox(
	const float4 origin, const float4 dir, const float4 bbMin, const float4 bbMax,
	float* tNear, float* tFar
) {
	float4 invDir = native_recip( dir );
	float4 t1 = ( bbMin - origin ) * invDir;
	float4 tMax = ( bbMax - origin ) * invDir;
	float4 tMin = fmin( t1, tMax );
	tMax = fmax( t1, tMax );

	*tNear = fmax( fmax( tMin.x, tMin.y ), tMin.z );
	*tFar = fmin( fmin( tMax.x, tMax.y ), fmin( tMax.z, *tFar ) );

	return ( *tNear <= *tFar );
}


/**
 * Basically a shortened version of udpateEntryDistanceAndExitRope().
 * @param {const float4*} origin
 * @param {const float4*} dir
 * @param {const float*}  bbMin
 * @param {const float*}  bbMax
 * @param {float*}        tFar
 */
void updateBoxExitLimit(
	const float4* origin, const float4* dir, const float4 bbMin, const float4 bbMax, float* tFar
) {
	float4 t1 = native_divide( bbMin - (*origin), *dir );
	float4 tMax = native_divide( bbMax - (*origin), *dir );
	tMax = fmax( t1, tMax );

	*tFar = fmin( fmin( tMax.x, tMax.y ), tMax.z );
}


/**
 * Source: http://graphics.cg.uni-saarland.de/fileadmin/cguds/courses/ws0910/cg/rc/web_sites/Ziesche/
 * Which is based on: "An Efficient and Robust Ray–Box Intersection Algorithm", Williams et al.
 * @param {const float4*} origin
 * @param {const float4*} dir
 * @param {const float*}  bbMin
 * @param {const float*}  bbMax
 * @param {float*}        tFar
 * @param {int*}          exitRope
 */
void updateEntryDistanceAndExitRope(
	const float4* origin, const float4* dir, const float4 bbMin, const float4 bbMax,
	float* tFar, int* exitRope
) {
	const float4 invDir = native_recip( *dir ); // WARNING: native_
	const bool signX = signbit( invDir.x );
	const bool signY = signbit( invDir.y );
	const bool signZ = signbit( invDir.z );

	float4 t1 = native_divide( bbMin - (*origin), *dir );
	float4 tMax = native_divide( bbMax - (*origin), *dir );
	tMax = fmax( t1, tMax );

	*tFar = fmin( fmin( tMax.x, tMax.y ), tMax.z );
	*exitRope = ( *tFar == tMax.y ) ? 3 - signY : 1 - signX;
	*exitRope = ( *tFar == tMax.z ) ? 5 - signZ : *exitRope;
}


/**
 * Test, if a point is inside a given axis aligned bounding box.
 * @param  {const float*}  bbMin
 * @param  {const float*}  bbMax
 * @param  {const float4*} p
 * @return {bool}
 */
inline bool isInsideBoundingBox( const float* bbMin, const float* bbMax, const float4* p ) {
	return (
		p->x >= bbMin[0] && p->y >= bbMin[1] && p->z >= bbMin[2] &&
		p->x <= bbMax[0] && p->y <= bbMax[1] && p->z <= bbMax[2]
	);
}


/**
 * Face intersection test after Möller and Trumbore.
 * @param  {const float4*} origin
 * @param  {const float4*} dir
 * @param  {const float4*} a
 * @param  {const float4*} b
 * @param  {const float4*} c
 * @param  {const float}   tNear
 * @param  {const float}   tFar
 * @param  {hit_t*}        result
 * @return {float}
 */
inline float checkFaceIntersection_MoellerTrumbore(
	const float4 origin, const float4 dir, const float4 a, const float4 b, const float4 c,
	const float tNear, const float tFar
) {
	const float4 edge1 = b - a;
	const float4 edge2 = c - a;
	const float4 tVec = origin - a;
	const float4 pVec = cross( dir, edge2 );
	const float4 qVec = cross( tVec, edge1 );
	const float det = dot( edge1, pVec );
	const float invDet = native_recip( det ); // WARNING: native_
	float t = dot( edge2, qVec ) * invDet;

	#define MT_FINAL_T_TEST fmax( t - tFar, tNear - t ) > EPSILON || t < EPSILON

	#ifdef BACKFACE_CULLING
		const float u = dot( tVec, pVec );
		const float v = dot( dir, qVec );

		t = ( fmin( u, v ) < 0.0f || u > det || u + v > det || MT_FINAL_T_TEST ) ? -2.0f : t;
	#else
		const float u = dot( tVec, pVec ) * invDet;
		const float v = dot( dir, qVec ) * invDet;

		t = ( fmin( u, v ) < 0.0f || u > 1.0f || u + v > 1.0f || MT_FINAL_T_TEST ) ? -2.0f : t;
	#endif

	return t;
}


inline float checkFaceIntersection_Barycentric(
	const float4 origin, const float4 dir, const float4 a, const float4 b, const float4 c,
	const float tNear, const float tFar
) {
	float4 edge1 = c - a;
	float4 edge2 = b - a;
	float4 oa = origin - a;
	float4 planeNormal = cross( edge1, edge2 );

	float t = native_divide( -dot( oa, planeNormal ), dot( dir, planeNormal ) );

	if( t < EPSILON || t < tNear - EPSILON || t > tFar + EPSILON ) {
		return -2.0f;
	}

	float4 hit = oa + t * dir;

	float uDotU = dot( edge1, edge1 );
	float uDotV = dot( edge1, edge2 );
	float vDotV = dot( edge2, edge2 );
	float wDotV = dot( hit, edge2 );
	float wDotU = dot( hit, edge1 );

	float d = native_recip( uDotV * uDotV - uDotU * vDotV );
	float beta = ( uDotV * wDotV - vDotV * wDotU ) * d;
	float gamma = ( uDotV * wDotU - uDotU * wDotV ) * d;

	if( beta < 0.0f || gamma < 0.0f || beta + gamma > 1.0f ) {
		return -2.0f;
	}

	return t;
}
