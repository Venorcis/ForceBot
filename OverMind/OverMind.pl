:- dynamic
% Static Percepts
	base/6,			% (isStart, minerals, gas, x, y, regionid)
	chokepoint/6,		% (x1, y1, x2, y2, regionid1, regionid2)
	enemyRace/1,		% (race)
	map/2,			% (width, height)
	region/5,		% (regionid, x, y, height, connections)

% Dynamic Percepts
	friendly/2,		% (id, type)
	gameframe/1,		% (frame)
	sliceSmall/1,		% (last 48 frame slice)
	sliceLarge/1,		% (last 240 frame slice)
	resources/4,		% (minerals, gas, currentSupply, totalSupply)
	mineralField/4,		% (mineralid, x, y, regionid)
	vespeneGeyser/4,	% (geyserid, x, y, regionid)
	underConstruction/5,	% (id, type, x, y, regionid)
	
% Additional Dynamic Percepts
	mineralBlock/4,		% (mineralid, x, y, regionid)
	chokepointBlocked/2,	% (regionid1, regionid2)
	
% Opening/Strategy beliefs
	openingUsed/1,		% (opening)
	timing/3,		% (dronecount, thing, type)
	currentStrategy/3,	% (name, requirements, dronesPerHatchery)
	completed5Pool/0,	% 
	droneLock/0,		% 
	gasLock/0,		% 
	numberOfBases/1,	% (numberOfHarvestingBases)
	numberOfHatcheries/1,	% (amount)
	
% Opening/Strategy beliefs
	vultureSpotted/0,	% (opening)
	siegeTankSpotted/0,	% (dronecount, thing, type)
	carrierSpotted/0,	% (name, requirements, dronesPerHatchery)

% General Beliefs
	agent/2,		% (id, agent)

% Training Beliefs
	larva/3,		% (id, agent, regionid)
	morphing/2,		% (id, type)

% Drone Beliefs
	buildTarget/4,		% (droneid, x, y, regionid)
	task/3,			% (droneid, task, target)
	minersMinerals/2,	% (regionid, miners)
	minersGas/2,		% (regionid, miners)
	mineralPatches/2,	% (regionid, amount)
	
% Gathering Beliefs
	mineralFieldN/5,	% (mineralid, x, y, regionid, amountOfWorkers)
	dedicatedPatch/2,	% (droneid, mineralid)
	extractorRegion/2,	% (id, regionid)
	
% Build Beliefs
	unitAmount/2,		% (type, amount)
	resources/4,		% (minerals, gas, currentsupply, totalsupply)
	costOverhead/2,		% (minerals, gas)
	producingUnit/2,	% (type, amount)
	
% Research Beliefs
	researching/2,		% (id, research)
	researchLevel/2,	% (research, level)
	
% Overlord Beliefs
	overlordRequest/4,	% (id, agent, x, y)
	overlordOrder/3,	% (id, order, target)
	scout/3,		% (x, y, regionid)
	ownMain/3,		% (x, y, regionid)
	ownNatural/3,		% (x, y, regionid)
	ownBase/4,		% (id, x, y, regionid)
	baseIsDangerous/3,	% (x, y, regionid)
	enemyMain/3,		% (x, y, regionid)
	enemyNatural/3,		% (x, y, regionid)
	enemyBase/3,		% (x, y, regionid)
	regionUnderAttack/1	% (regionid)
.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% GENERIC FUNCTIONS %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Calculate distance between two points
distance(X1, Y1, X2, Y2, D) :- D is sqrt((X2 - X1)**2 + (Y2 - Y1)**2).
% Calculate distance between two points, but do not root it (faster)
distanceSq(X1, Y1, X2, Y2, D) :- D is (X2 - X1)**2 + (Y2 - Y1)**2.

% Retrieves all elements different between two lists
listDifference(L1, L2, Remainder) :- subtract(L1, L2, R1), subtract(L2, L1, R2), append(R1, R2, Remainder).

% Determines the amount of actual resources that we have to spend
effectiveResources(Minerals, Gas, CS, TS) :-
	resources(M, G, CS, TS), costOverhead(MO, GO), Minerals is M - MO, Gas is G - GO.

% Determines whether we have at least the given amount of Drones
meetsDroneCount(Count) :- totalUnitAmount('Zerg Drone', Drones), Drones >= Count.

% Determines whether we meet all building and research requirements
meetsRequirements([]).
meetsRequirements([H|T]) :- (friendly(_, H) ; researchLevel(H, 1)), meetsRequirements(T).
meetsRequirements(['Zerg Spire'|T]) :- friendly(_, 'Zerg Greater Spire'), meetsRequirements(T).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% WORKER FUNCTIONS %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fetches best current patch to gather from

getBestMineralField(RegionId, MineralId1) :-
	ownBase(_, Xb, Yb, RegionId),
	Xd is Xb + 2, % the (X,Y) of the main hatchery in a region is always base(X + 2,Y + 1)
	Yd is Yb + 1,
	mineralFieldN(MineralId1, X1, Y1, RegionId, N1),
	D1 is (Xd - X1) ^ 2 + (Yd - Y1) ^ 2,
	% Make sure there isn't a better patch
	\+ (mineralFieldN(_, X2, Y2, RegionId, N2),
		(N2 > N1 ;
		(N2 = N1, (Xd - X2) ^ 2 + (Yd - Y2) ^ 2 < D1))).

% Get expansion with gas
getValidExpansion(X1, Y1, RegionId, true) :- base(_, _, Gas, X1, Y1, RegionId), Gas > 0, not(ownBase(_, X1, Y1, RegionId)),
	not(baseIsDangerous(X1, Y1, RegionId)), not(enemyBase(X1, Y1, RegionId)), not(buildTarget(_, X1, Y1, RegionId)),
	X2 is X1 + 2, Y2 is Y1 + 1, not(underConstruction(_, _, X2, Y2, RegionId)).
% Get expansion without gas
getValidExpansion(X1, Y1, RegionId, false) :- base(_, _, 0, X1, Y1, RegionId), not(ownBase(_, X1, Y1, RegionId)),
	not(baseIsDangerous(X1, Y1, RegionId)), not(enemyBase(X1, Y1, RegionId)), not(buildTarget(_, X1, Y1, RegionId)),
	X2 is X1 + 2, Y2 is Y1 + 1, not(underConstruction(_, _, X2, Y2, RegionId)).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% UNIT FUNCTIONS %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Determines the total amount of units we have for a given unit
totalUnitAmount(Unit, 0) :- not(producingUnit(Unit, _)), not(unitAmount(Unit, _)).
totalUnitAmount(Unit, Amount) :- producingUnit(Unit, Amount), not(unitAmount(Unit, _)).
totalUnitAmount(Unit, Amount) :- not(producingUnit(Unit, _)), unitAmount(Unit, Amount).
totalUnitAmount(Unit, Amount) :- producingUnit(Unit, A1), unitAmount(Unit, A2), Amount is A1 + A2.

% Fetches a random Hatchery or greater %% TODO: Is this still necessary?
getRandomUnit('Zerg Hatchery', Id, Agent) :- 
	findall(A1, friendly(A1, 'Zerg Hatchery'), List1), findall(A2, friendly(A2, 'Zerg Lair'), List2), findall(A3, friendly(A3, 'Zerg Hive'), List3), 
	append(List1, List2, List12), append(List12, List3, List123), 
	length(List123, Length), Length > 0, random_between(1, Length, Index), nth1(Index, List123, Id), agent(Id, Agent).
% Fetches a random Lair or greater
getRandomUnit('Zerg Lair', Id, Agent) :- 
	findall(A1, friendly(A1, 'Zerg Lair'), List1), findall(A2, friendly(A2, 'Zerg Hive'), List2),
	append(List1, List2, List12),
	length(List12, Length), Length > 0, random_between(1, Length, Index), nth1(Index, List12, Id), agent(Id, Agent).
% Fetches a random Spire or greater
getRandomUnit('Zerg Spire', Id, Agent) :- 
	findall(A1, friendly(A1, 'Zerg Spire'), List1), findall(A2, friendly(A2, 'Zerg Greater Spire'), List2),
	append(List1, List2, List12), 
	length(List12, Length), Length > 0, random_between(1, Length, Index), nth1(Index, List12, Id), agent(Id, Agent).
% Fetches a random unit
getRandomUnit(Type, Id, Agent) :- 
	findall(A, friendly(A, Type), List),
	length(List, Length), Length > 0, random_between(1, Length, Index), nth1(Index, List, Id), agent(Id, Agent).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% CONSTRUCTION/MORPHING FUNCTIONS %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Determines if we have the required resources/tech to create the given thing.
canCreate(Thing) :- costs(Thing, MinC, GasC, SupplyCost, _, Requirements), effectiveResources(Min, Gas, CS, TS),
	Min >= MinC, (Gas >= GasC ; GasC = 0), (CS + SupplyCost =< TS ; SupplyCost =< 0), meetsRequirements(Requirements).

% (morphedUnit, initialUnit, mineralCost, gasCost)
morph('Zerg Greater Spire', 'Zerg Spire', 100, 150).
morph('Zerg Hive', 'Zerg Lair', 200, 150).
morph('Zerg Lair', 'Zerg Hatchery', 150, 100).
morph('Zerg Spore Colony', 'Zerg Creep Colony', 50, 0).
morph('Zerg Sunken Colony', 'Zerg Creep Colony', 50, 0).
morph('Zerg Lurker', 'Zerg Hydralisk', 50, 100).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% RESEARCH FUNCTIONS %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Determines if we can perform a research
canResearch(Thing) :-
	not(isMultiResearch(Thing)), hasResearchLevelRemaining(Thing), not(researching(_, Thing)), % Make sure we're haven't already researched it
	costs(Thing, _, _, _, _, Requirements), nth0(0, Requirements, Requirement), friendly(Id, Requirement), % Find researcher unit
	not(researching(Id, _)), not(morphing(Id, _)). % Confirm it is available

% Determines if we can perform a research for multi-level researches
canResearch(Thing) :-
	isMultiResearch(Thing), hasResearchLevelRemaining(Thing), not(researching(_, Thing)), % Make sure we're haven't already researched it
	researchLevel(Thing, Level), NextLevel is Level + 1, atomic_list_concat([Thing, ' ', NextLevel], ThingLevel), % Construct the next level string
	costs(ThingLevel, _, _, _, _, Requirements), nth0(0, Requirements, Requirement), friendly(Id, Requirement), % Find researcher unit
	not(researching(Id, _)), not(morphing(Id, _)). % Confirm it is available

% Determine if we can research it (again)
hasResearchLevelRemaining(Thing) :- not(researchLevel(Thing, _)).
hasResearchLevelRemaining(Thing) :- researchLevel(Thing, Level), Level < 1.
hasResearchLevelRemaining(Thing) :- researchLevel(Thing, Level), isMultiResearch(Thing), friendly(_, 'Zerg Lair'), Level < 2.
hasResearchLevelRemaining(Thing) :- researchLevel(Thing, Level), isMultiResearch(Thing), friendly(_, 'Zerg Hive'), Level < 3.

% Determines if the research can be performed multiple times
isMultiResearch('Zerg Melee Attacks').
isMultiResearch('Zerg Missile Attacks').
isMultiResearch('Zerg Carapace').
isMultiResearch('Zerg Flyer Attacks').
isMultiResearch('Zerg Flyer Carapace').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% TYPE CHECKS %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% All structures
isBuilding('Protoss Arbiter Tribunal').
isBuilding('Protoss Assimilator').
isBuilding('Protoss Citadel of Adun').
isBuilding('Protoss Cybernetics Core').
isBuilding('Protoss Fleet Beacon').
isBuilding('Protoss Forge').
isBuilding('Protoss Gateway').
isBuilding('Protoss Nexus').
isBuilding('Protoss Observatory').
isBuilding('Protoss Photon Cannon').
isBuilding('Protoss Pylon').
isBuilding('Protoss Robotics Facility').
isBuilding('Protoss Robotics Support Bay').
isBuilding('Protoss Shield Battery').
isBuilding('Protoss Stargate').
isBuilding('Protoss Templar Archives').
isBuilding('Terran Academy').
isBuilding('Terran Armory').
isBuilding('Terran Bunker').
isBuilding('Terran Barracks').
isBuilding('Terran Command Center').
isBuilding('Terran Engineering Bay').
isBuilding('Terran Factory').
isBuilding('Terran Missile Turret').
isBuilding('Terran Refinery').
isBuilding('Terran Science Facility').
isBuilding('Terran Starport').
isBuilding('Terran Supply Depot').
isBuilding('Zerg Creep Colony').
isBuilding('Zerg Defiler Mound').
isBuilding('Zerg Evolution Chamber').
isBuilding('Zerg Extractor').
isBuilding('Zerg Greater Spire').
isBuilding('Zerg Hatchery').
isBuilding('Zerg Hive').
isBuilding('Zerg Hydralisk Den').
isBuilding('Zerg Infested Command Center').
isBuilding('Zerg Lair').
isBuilding('Zerg Nydus Canal').
isBuilding('Zerg Queens Nest').
isBuilding('Zerg Spawning Pool').
isBuilding('Zerg Spire').
isBuilding('Zerg Spore Colony').
isBuilding('Zerg Sunken Colony').
isBuilding('Zerg Ultralisk Cavern').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% OPENING LOGIC %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
countStartingLocations(Amount) :- aggregate_all(count, base(true, _, _, _, _, _), Amount).

%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% OPENINGS %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%
% Not included:
% - Trigger to morph Lair on first 100 gas
opening('ZVP_5Pool',[
timing(5, 'Zerg Spawning Pool', 'build'),
timing(9, 'Zerg Hatchery', 'build'),
timing(11, 'Zerg Extractor', 'build')
], 'Hydralisks').

% Not included:
% - Trigger to morph Lair on first 100 gas
opening('ZVT_5Pool',[
timing(5, 'Zerg Spawning Pool', 'build'),
timing(9, 'Zerg Hatchery', 'build'),
timing(11, 'Zerg Extractor', 'build')
], 'Hydralisks').

% Not included:
% - Trigger to research Metabolic Boost on first 100 gas
% - Trigger to morph Lair on second 100 gas
opening('ZVZ_9Pool',[
timing(9, 'Zerg Spawning Pool', 'build'),
timing(10, 'Zerg Creep Colony', 'build'),
timing(11, 'Zerg Creep Colony', 'build')
], 'Mutalisks').

% Not included:
% - Trigger to research Metabolic Boost on first 100 gas
% - Trigger to morph Lair on second 100 gas
opening('ZVU_9Pool',[
timing(9, 'Zerg Spawning Pool', 'build')
], 'Zerglings').

% Not included:
% - Trigger to create 3 Sunken's on expansion
% - Trigger to research Metabolic Boost on first 100 gas
% - Trigger to morph Lair on second 100 gas
opening('ZVT_12Hatch',[
timing(12, 'Zerg Hatchery', 'expand'),
timing(13, 'Zerg Spawning Pool', 'build'),
timing(15, 'Zerg Extractor', 'build')
], 'HydraLurker').

% Not included:
% - Trigger to create 3 Sunken's on expansion
% - Trigger to research Metabolic Boost on first 100 gas
% - Trigger to morph Lair on second 100 gas
opening('ZVP_12Hatch',[
timing(11, 'Zerg Spawning Pool', 'build'),
timing(12, 'Zerg Hatchery', 'expand'),
timing(15, 'Zerg Extractor', 'build')
], 'HydraLurker').

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% STRATEGIES %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
meetsStrategyRequirements([], null).
meetsStrategyRequirements(['Zerg Lair' | _], 'Zerg Lair') :- not(buildingExists('Zerg Lair')), not(buildingExists('Zerg Hive')).
meetsStrategyRequirements(['Zerg Spire' | _], 'Zerg Spire') :- not(buildingExists('Zerg Spire')), not(buildingExists('Zerg Greater Spire')).
meetsStrategyRequirements([H | _], H) :- H \= 'Zerg Lair', H \= 'Zerg Spire', not(buildingExists(H)).
meetsStrategyRequirements([H | _], null) :- underConstruction(_, H, _, _, _).
meetsStrategyRequirements([_ | T], Result) :- meetsStrategyRequirements(T, Result).

buildingExists(Thing) :- friendly(_, Thing) ; underConstruction(_, Thing, _, _, _) ; task(_, _, Thing) ; morphing(_, Thing).

% (Name, Requirements, Hatcheries per Drones)
strategy('Zerglings',[
'Zerg Spawning Pool'
], 3).

strategy('Hydralisks',[
'Zerg Spawning Pool', 'Zerg Hydralisk Den'
], 5).

strategy('HydraLurker',[
'Zerg Spawning Pool', 'Zerg Hydralisk Den', 'Zerg Lair'
], 5).

strategy('UltraHydra',[
'Zerg Spawning Pool', 'Zerg Hydralisk Den', 'Zerg Lair', 'Zerg Evolution Chamber', 'Zerg Queens Nest', 'Zerg Hive', 'Zerg Ultralisk Cavern'
], 6).

strategy('Mutalisks',[
'Zerg Spawning Pool', 'Zerg Lair', 'Zerg Spire'
], 7).

strategy('MutaTech',[
'Zerg Spawning Pool', 'Zerg Lair', 'Zerg Spire', 'Zerg Queens Nest', 'Zerg Hive'
], 7).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% KNOWLEDGE.PL %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/* 
 - unit(name,race)
	> all unit types for each race
 - tech(name,race)
	> all tech types for each race
 - upgrade(name,race)
	> all upgrade types for each race

 - costs(name,minerals,gas,supplyOrEnergy,buildFrames,requiredUnitsAndOrTechList)
 	> supply can be negative for e.g. an overlord, pylon or supply depot
	> energy is only applicable to tech types (i.e. when used as ability)
	> upgrade types can have multiple levels which are appended to the name in this predicate only
 - stats(name,maxHealth,maxShield,maxEnergy,speed,conditionsList)
	> only there for unit types; invincible units (such as spells) have a max health and shield of 0
	> possible conditions are: [addon,building,canBurrow,canDetect,canLift,canMove,canTrain,flies,
					mechanical,organic,requiresCreep,requiresPsi,robotic,spell]
 - metrics(name,width,height,sightRange,spaceRequired)
	> only there for unit types; all measures are in (build)tiles
	> spaceRequired can be negative for e.g. a overlord, shuttle or bunker
 - combat(name,groundDamage,airDamage,cooldownFrames,range,splashRadius)
	> only there for units that can attack or specific tech types (i.e. offensive abilities)
	> if the ground or air damage is 0, the unit cannot attack ground or air respectively
*/


%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% UNIT TYPES %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

unit('Terran Marine',terran).
costs('Terran Marine',50,0,2,360,['Terran Barracks']).
stats('Terran Marine',40,0,0,40,['canMove','organic']).
metrics('Terran Marine',1,1,7,1).
combat('Terran Marine',6,6,15,4,0).

unit('Terran Ghost',terran).
costs('Terran Ghost',25,75,2,750,['Terran Academy','Terran Covert Ops','Terran Barracks']).
stats('Terran Ghost',45,0,200,40,['canMove','organic']).
metrics('Terran Ghost',1,1,9,1).
combat('Terran Ghost',10,10,22,7,0).

unit('Terran Vulture',terran).
costs('Terran Vulture',75,0,4,450,['Terran Factory']).
stats('Terran Vulture',80,0,0,64,['canMove','mechanical']).
metrics('Terran Vulture',1,1,8,2).
combat('Terran Vulture',20,0,30,5,0).

unit('Terran Goliath',terran).
costs('Terran Goliath',100,50,4,600,['Terran Factory','Terran Armory']).
stats('Terran Goliath',125,0,0,45,['canMove','mechanical']).
metrics('Terran Goliath',1,1,8,2).
combat('Terran Goliath',12,20,22,6,0).

unit('Terran Siege Tank',terran).
costs('Terran Siege Tank',150,100,4,750,['Terran Factory','Terran Machine Shop']).
stats('Terran Siege Tank',150,0,0,40,['canMove','mechanical']).
metrics('Terran Siege Tank',1,1,10,4).
combat('Terran Siege Tank',30,0,37,7,0).

unit('Terran SCV',terran).
costs('Terran SCV',50,0,2,300,['Terran Command Center']).
stats('Terran SCV',60,0,0,49,['canMove','mechanical','organic']).
metrics('Terran SCV',1,1,7,1).
combat('Terran SCV',5,0,15,0,0).

unit('Terran Wraith',terran).
costs('Terran Wraith',150,100,4,900,['Terran Starport']).
stats('Terran Wraith',120,0,200,66,['canMove','flies','mechanical']).
metrics('Terran Wraith',1,1,7,0).
combat('Terran Wraith',8,20,30,5,0).

unit('Terran Science Vessel',terran).
costs('Terran Science Vessel',100,225,4,1200,['Terran Starport','Terran Control Tower','Terran Science Facility']).
stats('Terran Science Vessel',200,0,200,50,['canDetect','canMove','flies','mechanical']).
metrics('Terran Science Vessel',2,2,10,0).

unit('Terran Dropship',terran).
costs('Terran Dropship',100,100,4,750,['Terran Starport','Terran Control Tower']).
stats('Terran Dropship',150,0,0,54,['canMove','flies','mechanical']).
metrics('Terran Dropship',2,2,8,-8).

unit('Terran Battlecruiser',terran).
costs('Terran Battlecruiser',400,300,12,2000,['Terran Starport','Terran Control Tower','Terran Physics Lab']).
stats('Terran Battlecruiser',500,0,200,25,['canMove','flies','mechanical']).
metrics('Terran Battlecruiser',2,2,11,0).
combat('Terran Battlecruiser',25,25,30,6,0).

unit('Terran Vulture Spider Mine',terran).
costs('Terran Vulture Spider Mine',1,0,0,1,[]).
stats('Terran Vulture Spider Mine',20,0,0,160,['canMove']).
metrics('Terran Vulture Spider Mine',1,1,3,0).
combat('Terran Vulture Spider Mine',125,0,22,0,2).

unit('Terran Firebat',terran).
costs('Terran Firebat',50,25,2,360,['Terran Academy','Terran Barracks']).
stats('Terran Firebat',50,0,0,40,['canMove','organic']).
metrics('Terran Firebat',1,1,7,1).
combat('Terran Firebat',8,0,22,1,0).

unit('Spell Scanner Sweep',terran).
costs('Spell Scanner Sweep',0,0,0,1,[]).
stats('Spell Scanner Sweep',0,0,0,0,['canDetect','flies','spell']).
metrics('Spell Scanner Sweep',1,1,10,0).

unit('Terran Medic',terran).
costs('Terran Medic',50,25,2,450,['Terran Academy','Terran Barracks']).
stats('Terran Medic',60,0,200,40,['canMove','organic']).
metrics('Terran Medic',1,1,9,1).

unit('Zerg Larva',zerg).
costs('Zerg Larva',1,1,0,1,['Zerg Hatchery']).
stats('Zerg Larva',25,0,0,0,['organic']).
metrics('Zerg Larva',1,1,4,0).

unit('Zerg Egg',zerg).
costs('Zerg Egg',1,1,0,1,['Zerg Larva']).
stats('Zerg Egg',200,0,0,0,['organic']).
metrics('Zerg Egg',1,1,4,0).

unit('Zerg Zergling',zerg).
costs('Zerg Zergling',50,0,1,420,['Zerg Larva','Zerg Spawning Pool']).
stats('Zerg Zergling',35,0,0,54,['canBurrow','canMove','organic']).
metrics('Zerg Zergling',1,1,5,1).
combat('Zerg Zergling',5,0,8,0,0).

unit('Zerg Hydralisk',zerg).
costs('Zerg Hydralisk',75,25,2,420,['Zerg Larva','Zerg Hydralisk Den']).
stats('Zerg Hydralisk',80,0,0,36,['canBurrow','canMove','organic']).
metrics('Zerg Hydralisk',1,1,6,2).
combat('Zerg Hydralisk',10,10,15,4,0).

unit('Zerg Ultralisk',zerg).
costs('Zerg Ultralisk',200,200,8,900,['Zerg Larva','Zerg Ultralisk Cavern']).
stats('Zerg Ultralisk',400,0,0,51,['canMove','organic']).
metrics('Zerg Ultralisk',2,2,7,4).
combat('Zerg Ultralisk',20,0,15,0,0).

unit('Zerg Drone',zerg).
costs('Zerg Drone',50,0,2,300,['Zerg Larva']).
stats('Zerg Drone',40,0,0,49,['canBurrow','canMove','organic']).
metrics('Zerg Drone',1,1,7,1).
combat('Zerg Drone',5,0,22,1,0).

unit('Zerg Overlord',zerg).
costs('Zerg Overlord',100,0,-16,600,['Zerg Larva']).
stats('Zerg Overlord',200,0,0,8,['canDetect','canMove','flies','organic']).
metrics('Zerg Overlord',2,2,9,-8).

unit('Zerg Mutalisk',zerg).
costs('Zerg Mutalisk',100,100,4,600,['Zerg Larva','Zerg Spire']).
stats('Zerg Mutalisk',120,0,0,66,['canMove','flies','organic']).
metrics('Zerg Mutalisk',2,2,7,0).
combat('Zerg Mutalisk',9,9,30,3,0).

unit('Zerg Guardian',zerg).
costs('Zerg Guardian',50,100,4,600,['Zerg Greater Spire','Zerg Mutalisk']).
stats('Zerg Guardian',150,0,0,25,['canMove','flies','organic']).
metrics('Zerg Guardian',2,2,11,0).
combat('Zerg Guardian',20,0,30,8,0).

unit('Zerg Queen',zerg).
costs('Zerg Queen',100,100,4,750,['Zerg Larva','Zerg Queens Nest']).
stats('Zerg Queen',120,0,200,66,['canMove','flies','organic']).
metrics('Zerg Queen',2,2,10,0).

unit('Zerg Defiler',zerg).
costs('Zerg Defiler',50,150,4,750,['Zerg Larva','Zerg Defiler Mound']).
stats('Zerg Defiler',80,0,200,40,['canBurrow','canMove','organic']).
metrics('Zerg Defiler',1,1,10,2).

unit('Zerg Scourge',zerg).
costs('Zerg Scourge',25,75,1,450,['Zerg Larva','Zerg Spire']).
stats('Zerg Scourge',25,0,0,66,['canMove','flies','organic']).
metrics('Zerg Scourge',1,1,5,0).
combat('Zerg Scourge',0,110,1,0,0).

unit('Terran Valkyrie',terran).
costs('Terran Valkyrie',250,125,6,750,['Terran Starport','Terran Control Tower','Terran Armory']).
stats('Terran Valkyrie',200,0,0,66,['canMove','flies','mechanical']).
metrics('Terran Valkyrie',2,2,8,0).
combat('Terran Valkyrie',0,12,64,6,1).

unit('Zerg Cocoon',zerg).
costs('Zerg Cocoon',1,1,0,1,['Zerg Greater Spire','Zerg Mutalisk']).
stats('Zerg Cocoon',200,0,0,0,['flies','organic']).
metrics('Zerg Cocoon',1,1,4,0).

unit('Protoss Corsair',protoss).
costs('Protoss Corsair',150,100,4,600,['Protoss Stargate']).
stats('Protoss Corsair',100,80,200,66,['canMove','flies','mechanical']).
metrics('Protoss Corsair',1,1,9,0).
combat('Protoss Corsair',0,5,8,5,1).

unit('Protoss Dark Templar',protoss).
costs('Protoss Dark Templar',125,100,4,750,['Protoss Gateway','Protoss Templar Archives']).
stats('Protoss Dark Templar',80,40,0,49,['canMove','organic']).
metrics('Protoss Dark Templar',1,1,7,2).
combat('Protoss Dark Templar',40,0,30,0,0).

unit('Zerg Devourer',zerg).
costs('Zerg Devourer',150,50,4,600,['Zerg Greater Spire','Zerg Mutalisk']).
stats('Zerg Devourer',250,0,0,50,['canMove','flies','organic']).
metrics('Zerg Devourer',2,2,10,0).
combat('Zerg Devourer',0,25,100,6,0).

unit('Protoss Dark Archon',protoss).
costs('Protoss Dark Archon',0,0,8,300,['Protoss Dark Templar','Protoss Dark Templar']).
stats('Protoss Dark Archon',25,200,200,49,['canMove']).
metrics('Protoss Dark Archon',1,1,10,4).

unit('Protoss Probe',protoss).
costs('Protoss Probe',50,0,2,300,['Protoss Nexus']).
stats('Protoss Probe',20,20,0,49,['canMove','mechanical','robotic']).
metrics('Protoss Probe',1,1,8,1).
combat('Protoss Probe',5,0,22,1,0).

unit('Protoss Zealot',protoss).
costs('Protoss Zealot',100,0,4,600,['Protoss Gateway']).
stats('Protoss Zealot',100,60,0,40,['canMove','organic']).
metrics('Protoss Zealot',1,1,7,2).
combat('Protoss Zealot',8,0,22,0,0).

unit('Protoss Dragoon',protoss).
costs('Protoss Dragoon',125,50,4,750,['Protoss Gateway','Protoss Cybernetics Core']).
stats('Protoss Dragoon',100,80,0,50,['canMove','mechanical']).
metrics('Protoss Dragoon',1,1,8,4).
combat('Protoss Dragoon',20,20,30,4,0).

unit('Protoss High Templar',protoss).
costs('Protoss High Templar',50,150,4,750,['Protoss Gateway','Protoss Templar Archives']).
stats('Protoss High Templar',40,40,200,32,['canMove','organic']).
metrics('Protoss High Templar',1,1,7,2).

unit('Protoss Archon',protoss).
costs('Protoss Archon',0,0,8,300,['Protoss High Templar','Protoss High Templar']).
stats('Protoss Archon',10,350,0,49,['canMove']).
metrics('Protoss Archon',1,1,8,4).
combat('Protoss Archon',30,30,20,2,0).

unit('Protoss Shuttle',protoss).
costs('Protoss Shuttle',200,0,4,900,['Protoss Robotics Facility']).
stats('Protoss Shuttle',80,60,0,44,['canMove','flies','mechanical','robotic']).
metrics('Protoss Shuttle',2,1,8,-8).

unit('Protoss Scout',protoss).
costs('Protoss Scout',275,125,6,1200,['Protoss Stargate']).
stats('Protoss Scout',150,100,0,50,['canMove','flies','mechanical']).
metrics('Protoss Scout',2,1,8,0).
combat('Protoss Scout',8,28,30,4,0).

unit('Protoss Arbiter',protoss).
costs('Protoss Arbiter',100,350,8,2400,['Protoss Stargate','Protoss Arbiter Tribunal']).
stats('Protoss Arbiter',200,150,200,50,['canMove','flies','mechanical']).
metrics('Protoss Arbiter',2,2,9,0).
combat('Protoss Arbiter',10,10,45,5,0).

unit('Protoss Carrier',protoss).
costs('Protoss Carrier',350,250,12,2100,['Protoss Stargate','Protoss Fleet Beacon']).
stats('Protoss Carrier',300,150,0,33,['canMove','canTrain','flies','mechanical']).
metrics('Protoss Carrier',2,2,11,0).
combat('Protoss Carrier',0,0,0,0,0).

unit('Protoss Interceptor',protoss).
costs('Protoss Interceptor',25,0,0,300,['Protoss Carrier']).
stats('Protoss Interceptor',40,40,0,133,['canMove','flies','mechanical']).
metrics('Protoss Interceptor',1,1,6,0).
combat('Protoss Interceptor',6,6,1,4,0).

unit('Protoss Reaver',protoss).
costs('Protoss Reaver',200,100,8,1050,['Protoss Robotics Facility','Protoss Robotics Support Bay']).
stats('Protoss Reaver',100,80,0,17,['canMove','canTrain','mechanical','robotic']).
metrics('Protoss Reaver',1,1,10,4).
combat('Protoss Reaver',0,0,0,0,0).

unit('Protoss Observer',protoss).
costs('Protoss Observer',25,75,2,600,['Protoss Robotics Facility','Protoss Observatory']).
stats('Protoss Observer',40,20,0,33,['canDetect','canMove','flies','mechanical','robotic']).
metrics('Protoss Observer',1,1,9,0).

unit('Protoss Scarab',protoss).
costs('Protoss Scarab',15,0,0,105,['Protoss Reaver']).
stats('Protoss Scarab',0,0,0,160,['canMove','mechanical']).
metrics('Protoss Scarab',1,1,5,0).
combat('Protoss Scarab',100,0,1,4,1).

unit('Zerg Lurker Egg',zerg).
costs('Zerg Lurker Egg',1,1,0,1,['Lurker Aspect','Zerg Hydralisk']).
stats('Zerg Lurker Egg',200,0,0,0,['organic']).
metrics('Zerg Lurker Egg',1,1,4,0).

unit('Zerg Lurker',zerg).
costs('Zerg Lurker',50,100,4,600,['Lurker Aspect','Zerg Hydralisk']).
stats('Zerg Lurker',125,0,0,58,['canBurrow','canMove','organic']).
metrics('Zerg Lurker',1,1,8,4).
combat('Zerg Lurker',20,0,37,6,0).

unit('Spell Disruption Web',protoss).
costs('Spell Disruption Web',250,250,0,2400,[]).
stats('Spell Disruption Web',0,0,0,0,['spell']).
metrics('Spell Disruption Web',4,3,8,0).

unit('Terran Command Center',terran).
costs('Terran Command Center',400,0,-20,1800,['Terran SCV']).
stats('Terran Command Center',1500,0,0,10,['building','canLift','canTrain','mechanical']).
metrics('Terran Command Center',4,3,10,0).

unit('Terran Comsat Station',terran).
costs('Terran Comsat Station',50,50,0,600,['Terran Academy','Terran Command Center']).
stats('Terran Comsat Station',500,0,200,0,['addon','building','mechanical']).
metrics('Terran Comsat Station',2,2,10,0).

unit('Terran Nuclear Silo',terran).
costs('Terran Nuclear Silo',100,100,0,1200,['Terran Science Facility','Terran Covert Ops','Terran Command Center']).
stats('Terran Nuclear Silo',600,0,0,0,['addon','building','canTrain','mechanical']).
metrics('Terran Nuclear Silo',2,2,8,0).

unit('Terran Supply Depot',terran).
costs('Terran Supply Depot',100,0,-16,600,['Terran SCV']).
stats('Terran Supply Depot',500,0,0,0,['building','mechanical']).
metrics('Terran Supply Depot',3,2,8,0).

unit('Terran Refinery',terran).
costs('Terran Refinery',100,0,0,600,['Terran SCV']).
stats('Terran Refinery',750,0,0,0,['building','mechanical']).
metrics('Terran Refinery',4,2,8,0).

unit('Terran Barracks',terran).
costs('Terran Barracks',150,0,0,1200,['Terran SCV','Terran Command Center']).
stats('Terran Barracks',1000,0,0,10,['building','canLift','canTrain','mechanical']).
metrics('Terran Barracks',4,3,8,0).

unit('Terran Academy',terran).
costs('Terran Academy',150,0,0,1200,['Terran SCV','Terran Barracks']).
stats('Terran Academy',600,0,0,0,['building','mechanical']).
metrics('Terran Academy',3,2,8,0).

unit('Terran Factory',terran).
costs('Terran Factory',200,100,0,1200,['Terran SCV','Terran Barracks']).
stats('Terran Factory',1250,0,0,10,['building','canLift','canTrain','mechanical']).
metrics('Terran Factory',4,3,8,0).

unit('Terran Starport',terran).
costs('Terran Starport',150,100,0,1050,['Terran Factory','Terran SCV']).
stats('Terran Starport',1300,0,0,10,['building','canLift','canTrain','mechanical']).
metrics('Terran Starport',4,3,10,0).

unit('Terran Control Tower',terran).
costs('Terran Control Tower',50,50,0,600,['Terran Starport']).
stats('Terran Control Tower',500,0,0,0,['addon','building','mechanical']).
metrics('Terran Control Tower',2,2,8,0).

unit('Terran Science Facility',terran).
costs('Terran Science Facility',100,150,0,900,['Terran Starport','Terran SCV']).
stats('Terran Science Facility',850,0,0,10,['building','canLift','mechanical']).
metrics('Terran Science Facility',4,3,10,0).

unit('Terran Covert Ops',terran).
costs('Terran Covert Ops',50,50,0,600,['Terran Science Facility']).
stats('Terran Covert Ops',750,0,0,0,['addon','building','mechanical']).
metrics('Terran Covert Ops',2,2,8,0).

unit('Terran Physics Lab',terran).
costs('Terran Physics Lab',50,50,0,600,['Terran Science Facility']).
stats('Terran Physics Lab',600,0,0,0,['addon','building','mechanical']).
metrics('Terran Physics Lab',2,2,8,0).

unit('Terran Machine Shop',terran).
costs('Terran Machine Shop',50,50,0,600,['Terran Factory']).
stats('Terran Machine Shop',750,0,0,0,['addon','building','mechanical']).
metrics('Terran Machine Shop',2,2,8,0).

unit('Terran Engineering Bay',terran).
costs('Terran Engineering Bay',125,0,0,900,['Terran SCV','Terran Command Center']).
stats('Terran Engineering Bay',850,0,0,10,['building','canLift','mechanical']).
metrics('Terran Engineering Bay',4,3,8,0).

unit('Terran Armory',terran).
costs('Terran Armory',100,50,0,1200,['Terran Factory','Terran SCV']).
stats('Terran Armory',750,0,0,0,['building','mechanical']).
metrics('Terran Armory',3,2,8,0).

unit('Terran Missile Turret',terran).
costs('Terran Missile Turret',75,0,0,450,['Terran SCV','Terran Engineering Bay']).
stats('Terran Missile Turret',200,0,0,0,['building','canDetect','mechanical']).
metrics('Terran Missile Turret',2,2,11,0).
combat('Terran Missile Turret',0,20,15,7,0).

unit('Terran Bunker',terran).
costs('Terran Bunker',100,0,0,450,['Terran SCV','Terran Barracks']).
stats('Terran Bunker',350,0,0,0,['building','mechanical']).
metrics('Terran Bunker',3,2,10,-4).

unit('Zerg Hatchery',zerg).
costs('Zerg Hatchery',300,0,-2,1800,['Zerg Drone']).
stats('Zerg Hatchery',1250,0,0,0,['building','canTrain','organic']).
metrics('Zerg Hatchery',4,3,9,0).

unit('Zerg Lair',zerg).
costs('Zerg Lair',150,100,-2,1500,['Zerg Hatchery','Zerg Spawning Pool']).
stats('Zerg Lair',1800,0,0,0,['building','canTrain','organic']).
metrics('Zerg Lair',4,3,10,0).

unit('Zerg Hive',zerg).
costs('Zerg Hive',200,150,-2,1800,['Zerg Lair','Zerg Queens Nest']).
stats('Zerg Hive',2500,0,0,0,['building','canTrain','organic']).
metrics('Zerg Hive',4,3,11,0).

unit('Zerg Nydus Canal',zerg).
costs('Zerg Nydus Canal',150,0,0,600,['Zerg Hive','Zerg Drone']).
stats('Zerg Nydus Canal',250,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Nydus Canal',2,2,8,0).

unit('Zerg Hydralisk Den',zerg).
costs('Zerg Hydralisk Den',100,50,0,600,['Zerg Drone','Zerg Spawning Pool']).
stats('Zerg Hydralisk Den',850,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Hydralisk Den',3,2,8,0).

unit('Zerg Defiler Mound',zerg).
costs('Zerg Defiler Mound',100,100,0,900,['Zerg Hive','Zerg Drone']).
stats('Zerg Defiler Mound',850,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Defiler Mound',4,2,8,0).

unit('Zerg Greater Spire',zerg).
costs('Zerg Greater Spire',100,150,0,1800,['Zerg Spire']).
stats('Zerg Greater Spire',1000,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Greater Spire',2,2,8,0).

unit('Zerg Queens Nest',zerg).
costs('Zerg Queens Nest',150,100,0,900,['Zerg Lair','Zerg Drone']).
stats('Zerg Queens Nest',850,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Queens Nest',3,2,8,0).

unit('Zerg Evolution Chamber',zerg).
costs('Zerg Evolution Chamber',75,0,0,600,['Zerg Hatchery','Zerg Drone']).
stats('Zerg Evolution Chamber',750,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Evolution Chamber',3,2,8,0).

unit('Zerg Ultralisk Cavern',zerg).
costs('Zerg Ultralisk Cavern',150,200,0,1200,['Zerg Hive','Zerg Drone']).
stats('Zerg Ultralisk Cavern',600,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Ultralisk Cavern',3,2,8,0).

unit('Zerg Spire',zerg).
costs('Zerg Spire',200,150,0,1800,['Zerg Lair','Zerg Drone']).
stats('Zerg Spire',600,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Spire',2,2,8,0).

unit('Zerg Spawning Pool',zerg).
costs('Zerg Spawning Pool',200,0,0,1200,['Zerg Hatchery','Zerg Drone']).
stats('Zerg Spawning Pool',750,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Spawning Pool',3,2,8,0).

unit('Zerg Creep Colony',zerg).
costs('Zerg Creep Colony',75,0,0,300,['Zerg Drone']).
stats('Zerg Creep Colony',400,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Creep Colony',2,2,10,0).

unit('Zerg Spore Colony',zerg).
costs('Zerg Spore Colony',50,0,0,300,['Zerg Evolution Chamber','Zerg Creep Colony']).
stats('Zerg Spore Colony',400,0,0,0,['building','canDetect','organic','requiresCreep']).
metrics('Zerg Spore Colony',2,2,10,0).
combat('Zerg Spore Colony',0,15,15,7,0).

unit('Zerg Sunken Colony',zerg).
costs('Zerg Sunken Colony',50,0,0,300,['Zerg Spawning Pool','Zerg Creep Colony']).
stats('Zerg Sunken Colony',300,0,0,0,['building','organic','requiresCreep']).
metrics('Zerg Sunken Colony',2,2,10,0).
combat('Zerg Sunken Colony',40,0,32,7,0).

unit('Zerg Extractor',zerg).
costs('Zerg Extractor',50,0,0,600,['Zerg Drone']).
stats('Zerg Extractor',750,0,0,0,['building','organic']).
metrics('Zerg Extractor',4,2,7,0).

unit('Protoss Nexus',protoss).
costs('Protoss Nexus',400,0,-18,1800,['Protoss Probe']).
stats('Protoss Nexus',750,750,0,0,['building','canTrain','mechanical']).
metrics('Protoss Nexus',4,3,11,0).

unit('Protoss Robotics Facility',protoss).
costs('Protoss Robotics Facility',200,200,0,1200,['Protoss Probe','Protoss Cybernetics Core']).
stats('Protoss Robotics Facility',500,500,0,0,['building','canTrain','mechanical','requiresPsi']).
metrics('Protoss Robotics Facility',3,2,10,0).

unit('Protoss Pylon',protoss).
costs('Protoss Pylon',100,0,-16,450,['Protoss Probe']).
stats('Protoss Pylon',300,300,0,0,['building','mechanical']).
metrics('Protoss Pylon',2,2,8,0).

unit('Protoss Assimilator',protoss).
costs('Protoss Assimilator',100,0,0,600,['Protoss Probe']).
stats('Protoss Assimilator',450,450,0,0,['building','mechanical']).
metrics('Protoss Assimilator',4,2,10,0).

unit('Protoss Observatory',protoss).
costs('Protoss Observatory',50,100,0,450,['Protoss Probe','Protoss Robotics Facility']).
stats('Protoss Observatory',250,250,0,0,['building','mechanical','requiresPsi']).
metrics('Protoss Observatory',3,2,10,0).

unit('Protoss Gateway',protoss).
costs('Protoss Gateway',150,0,0,900,['Protoss Probe','Protoss Nexus']).
stats('Protoss Gateway',500,500,0,0,['building','canTrain','mechanical','requiresPsi']).
metrics('Protoss Gateway',4,3,10,0).

unit('Protoss Photon Cannon',protoss).
costs('Protoss Photon Cannon',150,0,0,750,['Protoss Probe','Protoss Forge']).
stats('Protoss Photon Cannon',100,100,0,0,['building','canDetect','mechanical','requiresPsi']).
metrics('Protoss Photon Cannon',2,2,11,0).
combat('Protoss Photon Cannon',20,20,22,7,0).

unit('Protoss Citadel of Adun',protoss).
costs('Protoss Citadel of Adun',150,100,0,900,['Protoss Probe','Protoss Cybernetics Core']).
stats('Protoss Citadel of Adun',450,450,0,0,['building','mechanical','requiresPsi']).
metrics('Protoss Citadel of Adun',3,2,10,0).

unit('Protoss Cybernetics Core',protoss).
costs('Protoss Cybernetics Core',200,0,0,900,['Protoss Probe','Protoss Gateway']).
stats('Protoss Cybernetics Core',500,500,0,0,['building','mechanical','requiresPsi']).
metrics('Protoss Cybernetics Core',3,2,10,0).

unit('Protoss Templar Archives',protoss).
costs('Protoss Templar Archives',150,200,0,900,['Protoss Probe','Protoss Citadel of Adun']).
stats('Protoss Templar Archives',500,500,0,0,['building','mechanical','requiresPsi']).
metrics('Protoss Templar Archives',3,2,10,0).

unit('Protoss Forge',protoss).
costs('Protoss Forge',150,0,0,600,['Protoss Probe','Protoss Nexus']).
stats('Protoss Forge',550,550,0,0,['building','mechanical','requiresPsi']).
metrics('Protoss Forge',3,2,10,0).

unit('Protoss Stargate',protoss).
costs('Protoss Stargate',150,150,0,1050,['Protoss Probe','Protoss Cybernetics Core']).
stats('Protoss Stargate',600,600,0,0,['building','canTrain','mechanical','requiresPsi']).
metrics('Protoss Stargate',4,3,10,0).

unit('Protoss Fleet Beacon',protoss).
costs('Protoss Fleet Beacon',300,200,0,900,['Protoss Probe','Protoss Stargate']).
stats('Protoss Fleet Beacon',500,500,0,0,['building','mechanical','requiresPsi']).
metrics('Protoss Fleet Beacon',3,2,10,0).

unit('Protoss Arbiter Tribunal',protoss).
costs('Protoss Arbiter Tribunal',200,150,0,900,['Protoss Probe','Protoss Templar Archives']).
stats('Protoss Arbiter Tribunal',500,500,0,0,['building','mechanical','requiresPsi']).
metrics('Protoss Arbiter Tribunal',3,2,10,0).

unit('Protoss Robotics Support Bay',protoss).
costs('Protoss Robotics Support Bay',150,100,0,450,['Protoss Probe','Protoss Robotics Facility']).
stats('Protoss Robotics Support Bay',450,450,0,0,['building','mechanical','requiresPsi']).
metrics('Protoss Robotics Support Bay',3,2,10,0).

unit('Protoss Shield Battery',protoss).
costs('Protoss Shield Battery',100,0,0,450,['Protoss Probe','Protoss Gateway']).
stats('Protoss Shield Battery',200,200,200,0,['building','mechanical','requiresPsi']).
metrics('Protoss Shield Battery',3,2,10,0).

unit('Spell Dark Swarm',zerg).
costs('Spell Dark Swarm',250,200,0,2400,[]).
stats('Spell Dark Swarm',0,0,0,0,['spell']).
metrics('Spell Dark Swarm',5,5,8,0).

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% TECH TYPES %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

tech('Stim Packs',terran).
costs('Stim Packs',100,100,0,1200,['Terran Academy']).

tech('Lockdown',terran).
costs('Lockdown',200,200,100,1500,['Terran Covert Ops']).
combat('Lockdown',0,0,1,8,0).

tech('EMP Shockwave',terran).
costs('EMP Shockwave',200,200,100,1800,['Terran Science Facility']).
combat('EMP Shockwave',0,0,1,8,2).

tech('Spider Mines',terran).
costs('Spider Mines',100,100,0,1200,['Terran Machine Shop']).
combat('Spider Mines',125,0,22,0,2).

tech('Scanner Sweep',terran).
costs('Scanner Sweep',0,0,50,0,['None']).

tech('Tank Siege Mode',terran).
costs('Tank Siege Mode',150,150,0,1200,['Terran Machine Shop']).

tech('Defensive Matrix',terran).
costs('Defensive Matrix',0,0,100,0,['None']).

tech('Irradiate',terran).
costs('Irradiate',200,200,75,1200,['Terran Science Facility']).
combat('Irradiate',250,250,75,9,0).

tech('Yamato Gun',terran).
costs('Yamato Gun',100,100,150,1800,['Terran Physics Lab']).
combat('Yamato Gun',260,260,15,10,0).

tech('Cloaking Field',terran).
costs('Cloaking Field',150,150,25,1500,['Terran Control Tower']).

tech('Personnel Cloaking',terran).
costs('Personnel Cloaking',100,100,25,1200,['Terran Covert Ops']).

tech('Burrowing',zerg).
costs('Burrowing',100,100,0,1200,['Zerg Hatchery']).

tech('Infestation',zerg).
costs('Infestation',0,0,0,0,['None']).

tech('Spawn Broodlings',zerg).
costs('Spawn Broodlings',100,100,150,1200,['Zerg Queens Nest']).
combat('Spawn Broodlings',0,0,1,9,0).

tech('Dark Swarm',zerg).
costs('Dark Swarm',0,0,100,0,['None']).
combat('Dark Swarm',0,0,1,9,0).

tech('Plague',zerg).
costs('Plague',200,200,150,1500,['Zerg Defiler Mound']).
combat('Plague',300,300,1,9,0).

tech('Consume',zerg).
costs('Consume',100,100,0,1500,['Zerg Defiler Mound']).
combat('Consume',0,0,1,0,0).

tech('Ensnare',zerg).
costs('Ensnare',100,100,75,1200,['Zerg Queens Nest']).
combat('Ensnare',0,0,1,9,0).

tech('Parasite',zerg).
costs('Parasite',0,0,75,0,['None']).
combat('Parasite',0,0,1,12,0).

tech('Psionic Storm',protoss).
costs('Psionic Storm',200,200,75,1800,['Protoss Templar Archives']).
combat('Psionic Storm',14,14,45,9,1).

tech('Hallucination',protoss).
costs('Hallucination',150,150,100,1200,['Protoss Templar Archives']).

tech('Recall',protoss).
costs('Recall',150,150,150,1800,['Protoss Arbiter Tribunal']).

tech('Stasis Field',protoss).
costs('Stasis Field',150,150,100,1500,['Protoss Arbiter Tribunal']).
combat('Stasis Field',0,0,1,9,0).

tech('Archon Warp',protoss).
costs('Archon Warp',0,0,0,0,['None']).

tech('Restoration',terran).
costs('Restoration',100,100,50,1200,['Terran Academy']).
combat('Restoration',20,20,22,6,0).

tech('Disruption Web',protoss).
costs('Disruption Web',200,200,125,1200,['Protoss Fleet Beacon']).
combat('Disruption Web',0,0,22,9,0).

tech('Nuclear Strike',terran).
costs('Nuclear Strike',0,0,0,0,['None']).
combat('Nuclear Strike',600,600,1,0,6).

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% UPGRADE TYPES %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

upgrade('Terran Infantry Armor',terran).
costs('Terran Infantry Armor 1',175,175,0,4480,['Terran Engineering Bay']).
costs('Terran Infantry Armor 2',250,250,0,4960,['Terran Engineering Bay']).
costs('Terran Infantry Armor 3',325,325,0,5440,['Terran Engineering Bay']).

upgrade('Terran Vehicle Plating',terran).
costs('Terran Vehicle Plating 1',175,175,0,4480,['Terran Armory']).
costs('Terran Vehicle Plating 2',250,250,0,4960,['Terran Armory']).
costs('Terran Vehicle Plating 3',325,325,0,5440,['Terran Armory']).

upgrade('Terran Ship Plating',terran).
costs('Terran Ship Plating 1',225,225,0,4480,['Terran Armory']).
costs('Terran Ship Plating 2',300,300,0,4960,['Terran Armory']).
costs('Terran Ship Plating 3',375,375,0,5440,['Terran Armory']).

upgrade('Zerg Carapace',zerg).
costs('Zerg Carapace 1',150,150,0,4480,['Zerg Evolution Chamber']).
costs('Zerg Carapace 2',225,225,0,4960,['Zerg Evolution Chamber']).
costs('Zerg Carapace 3',300,300,0,5440,['Zerg Evolution Chamber']).

upgrade('Zerg Flyer Carapace',zerg).
costs('Zerg Flyer Carapace 1',150,150,0,4480,['Zerg Spire']).
costs('Zerg Flyer Carapace 2',225,225,0,4960,['Zerg Spire']).
costs('Zerg Flyer Carapace 3',300,300,0,5440,['Zerg Spire']).

upgrade('Protoss Ground Armor',protoss).
costs('Protoss Ground Armor 1',175,175,0,4480,['Protoss Forge']).
costs('Protoss Ground Armor 2',250,250,0,4960,['Protoss Forge']).
costs('Protoss Ground Armor 3',325,325,0,5440,['Protoss Forge']).

upgrade('Protoss Air Armor',protoss).
costs('Protoss Air Armor 1',225,225,0,4480,['Protoss Cybernetics Core']).
costs('Protoss Air Armor 2',300,300,0,4960,['Protoss Cybernetics Core']).
costs('Protoss Air Armor 3',375,375,0,5440,['Protoss Cybernetics Core']).

upgrade('Terran Infantry Weapons',terran).
costs('Terran Infantry Weapons 1',175,175,0,4480,['Terran Engineering Bay']).
costs('Terran Infantry Weapons 2',250,250,0,4960,['Terran Engineering Bay']).
costs('Terran Infantry Weapons 3',325,325,0,5440,['Terran Engineering Bay']).

upgrade('Terran Vehicle Weapons',terran).
costs('Terran Vehicle Weapons 1',175,175,0,4480,['Terran Armory']).
costs('Terran Vehicle Weapons 2',250,250,0,4960,['Terran Armory']).
costs('Terran Vehicle Weapons 3',325,325,0,5440,['Terran Armory']).

upgrade('Terran Ship Weapons',terran).
costs('Terran Ship Weapons 1',150,150,0,4480,['Terran Armory']).
costs('Terran Ship Weapons 2',200,200,0,4960,['Terran Armory']).
costs('Terran Ship Weapons 3',250,250,0,5440,['Terran Armory']).

upgrade('Zerg Melee Attacks',zerg).
costs('Zerg Melee Attacks 1',100,100,0,4480,['Zerg Evolution Chamber']).
costs('Zerg Melee Attacks 2',150,150,0,4960,['Zerg Evolution Chamber']).
costs('Zerg Melee Attacks 3',200,200,0,5440,['Zerg Evolution Chamber']).

upgrade('Zerg Missile Attacks',zerg).
costs('Zerg Missile Attacks 1',100,100,0,4480,['Zerg Evolution Chamber']).
costs('Zerg Missile Attacks 2',150,150,0,4960,['Zerg Evolution Chamber']).
costs('Zerg Missile Attacks 3',200,200,0,5440,['Zerg Evolution Chamber']).

upgrade('Zerg Flyer Attacks',zerg).
costs('Zerg Flyer Attacks 1',100,100,0,4480,['Zerg Spire']).
costs('Zerg Flyer Attacks 2',175,175,0,4960,['Zerg Spire']).
costs('Zerg Flyer Attacks 3',250,250,0,5440,['Zerg Spire']).

upgrade('Protoss Ground Weapons',protoss).
costs('Protoss Ground Weapons 1',150,150,0,4480,['Protoss Forge']).
costs('Protoss Ground Weapons 2',200,200,0,4960,['Protoss Forge']).
costs('Protoss Ground Weapons 3',250,250,0,5440,['Protoss Forge']).

upgrade('Protoss Air Weapons',protoss).
costs('Protoss Air Weapons 1',175,175,0,4480,['Protoss Cybernetics Core']).
costs('Protoss Air Weapons 2',250,250,0,4960,['Protoss Cybernetics Core']).
costs('Protoss Air Weapons 3',325,325,0,5440,['Protoss Cybernetics Core']).

upgrade('Protoss Plasma Shields',protoss).
costs('Protoss Plasma Shields 1',300,300,0,4480,['Protoss Forge']).
costs('Protoss Plasma Shields 2',400,400,0,4960,['Protoss Forge']).
costs('Protoss Plasma Shields 3',500,500,0,5440,['Protoss Forge']).

upgrade('U-238 Shells',terran).
costs('U-238 Shells',150,150,0,1500,['Terran Academy']).

upgrade('Ion Thrusters',terran).
costs('Ion Thrusters',100,100,0,1500,['Terran Machine Shop']).

upgrade('Titan Reactor',terran).
costs('Titan Reactor',150,150,0,2500,['Terran Science Facility']).

upgrade('Ocular Implants',terran).
costs('Ocular Implants',100,100,0,2500,['Terran Covert Ops']).

upgrade('Moebius Reactor',terran).
costs('Moebius Reactor',150,150,0,2500,['Terran Covert Ops']).

upgrade('Apollo Reactor',terran).
costs('Apollo Reactor',200,200,0,2500,['Terran Control Tower']).

upgrade('Colossus Reactor',terran).
costs('Colossus Reactor',150,150,0,2500,['Terran Physics Lab']).

upgrade('Ventral Sacs',zerg).
costs('Ventral Sacs',200,200,0,2400,['Zerg Lair']).

upgrade('Antennae',zerg).
costs('Antennae',150,150,0,2000,['Zerg Lair']).

upgrade('Pneumatized Carapace',zerg).
costs('Pneumatized Carapace',150,150,0,2000,['Zerg Lair']).

upgrade('Metabolic Boost',zerg).
costs('Metabolic Boost',100,100,0,1500,['Zerg Spawning Pool']).

upgrade('Adrenal Glands',zerg).
costs('Adrenal Glands',200,200,0,1500,['Zerg Spawning Pool']).

upgrade('Muscular Augments',zerg).
costs('Muscular Augments',150,150,0,1500,['Zerg Hydralisk Den']).

upgrade('Grooved Spines',zerg).
costs('Grooved Spines',150,150,0,1500,['Zerg Hydralisk Den']).

upgrade('Lurker Aspect',zerg).
costs('Lurker Aspect',200,200,0,1800,['Zerg Hydralisk Den']).

upgrade('Gamete Meiosis',zerg).
costs('Gamete Meiosis',150,150,0,2500,['Zerg Queens Nest']).

upgrade('Metasynaptic Node',zerg).
costs('Metasynaptic Node',150,150,0,2500,['Zerg Defiler Mound']).

upgrade('Singularity Charge',protoss).
costs('Singularity Charge',150,150,0,2500,['Protoss Cybernetics Core']).

upgrade('Leg Enhancements',protoss).
costs('Leg Enhancements',150,150,0,2000,['Protoss Citadel of Adun']).

upgrade('Scarab Damage',protoss).
costs('Scarab Damage',200,200,0,2500,['Protoss Robotics Support Bay']).

upgrade('Reaver Capacity',protoss).
costs('Reaver Capacity',200,200,0,2500,['Protoss Robotics Support Bay']).

upgrade('Gravitic Drive',protoss).
costs('Gravitic Drive',200,200,0,2500,['Protoss Robotics Support Bay']).

upgrade('Sensor Array',protoss).
costs('Sensor Array',150,150,0,2000,['Protoss Observatory']).

upgrade('Gravitic Boosters',protoss).
costs('Gravitic Boosters',150,150,0,2000,['Protoss Observatory']).

upgrade('Khaydarin Amulet',protoss).
costs('Khaydarin Amulet',150,150,0,2500,['Protoss Templar Archives']).

upgrade('Apial Sensors',protoss).
costs('Apial Sensors',100,100,0,2500,['Protoss Fleet Beacon']).

upgrade('Gravitic Thrusters',protoss).
costs('Gravitic Thrusters',200,200,0,2500,['Protoss Fleet Beacon']).

upgrade('Carrier Capacity',protoss).
costs('Carrier Capacity',100,100,0,1500,['Protoss Fleet Beacon']).

upgrade('Khaydarin Core',protoss).
costs('Khaydarin Core',150,150,0,2500,['Protoss Arbiter Tribunal']).

upgrade('Argus Jewel',protoss).
costs('Argus Jewel',100,100,0,2500,['Protoss Fleet Beacon']).

upgrade('Argus Talisman',protoss).
costs('Argus Talisman',150,150,0,2500,['Protoss Templar Archives']).

upgrade('Caduceus Reactor',terran).
costs('Caduceus Reactor',150,150,0,2500,['Terran Academy']).

upgrade('Chitinous Plating',zerg).
costs('Chitinous Plating',150,150,0,2000,['Zerg Ultralisk Cavern']).

upgrade('Anabolic Synthesis',zerg).
costs('Anabolic Synthesis',200,200,0,2000,['Zerg Ultralisk Cavern']).

upgrade('Charon Boosters',terran).
costs('Charon Boosters',100,100,0,2000,['Terran Machine Shop']).