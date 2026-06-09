sub init()
	m.grid = m.top.findNode("grid")
	m.grid.setFocus(true)

	' Have to delay load probably due to weird main bug
	m.timer = createObject("roSGNode", "Timer")
	m.timer.duration = 0.1
	m.timer.observeField("fire", "onTimerFired")
	m.timer.control = "start"
end sub


sub onTimerFired()
	addGridContent()
end sub


sub addGridContent()
	rows = [
		{
			' "rowIndex": 0
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Popular Movies"
			}
			items: [
				{ "title": "Avatar The Way of Water", "imageUrl": "https://picsum.photos/seed/avatar-the-way-of-water" },
				{ "title": "Top Gun Maverick", "imageUrl": "https://picsum.photos/seed/top-gun-maverick" },
				{ "title": "Avengers Endgame", "imageUrl": "https://picsum.photos/seed/avengers-endgame" },
				{ "title": "Black Panther Wakanda Forever", "imageUrl": "https://picsum.photos/seed/black-panther-wakanda-forever" },
				{ "title": "Spider-Man No Way Home", "imageUrl": "https://picsum.photos/seed/spider-man-no-way-home" },
				{ "title": "Jurassic World Dominion", "imageUrl": "https://picsum.photos/seed/jurassic-world-dominion" },
				{ "title": "The Batman", "imageUrl": "https://picsum.photos/seed/the-batman" },
				{ "title": "Dune", "imageUrl": "https://picsum.photos/seed/dune" },
				{ "title": "Mission Impossible Fallout", "imageUrl": "https://picsum.photos/seed/mission-impossible-fallout" },
				{ "title": "Titanic", "imageUrl": "https://picsum.photos/seed/titanic-movie" },
				{ "title": "Inception", "imageUrl": "https://picsum.photos/seed/inception" },
				{ "title": "Interstellar", "imageUrl": "https://picsum.photos/seed/interstellar" },
				{ "title": "The Dark Knight", "imageUrl": "https://picsum.photos/seed/the-dark-knight" },
				{ "title": "Guardians of the Galaxy Vol 3", "imageUrl": "https://picsum.photos/seed/guardians-vol-3" },
				{ "title": "Frozen II", "imageUrl": "https://picsum.photos/seed/frozen-ii" },
				{ "title": "Toy Story 4", "imageUrl": "https://picsum.photos/seed/toy-story-4" },
				{ "title": "The Irishman", "imageUrl": "https://picsum.photos/seed/the-irishman" },
				{ "title": "Star Wars The Rise of Skywalker", "imageUrl": "https://picsum.photos/seed/star-wars-rise" },
				{ "title": "Parasite", "imageUrl": "https://picsum.photos/seed/parasite-movie" },
				{ "title": "Joker", "imageUrl": "https://picsum.photos/seed/joker-movie" }
			]
		},
		{
			' "rowIndex": 1
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Top Rated"
			}
			items: [
				{ "title": "The Shawshank Redemption", "imageUrl": "https://picsum.photos/seed/shawshank-redemption" },
				{ "title": "The Godfather", "imageUrl": "https://picsum.photos/seed/the-godfather" },
				{ "title": "The Godfather Part II", "imageUrl": "https://picsum.photos/seed/godfather-part-ii" },
				{ "title": "Pulp Fiction", "imageUrl": "https://picsum.photos/seed/pulp-fiction" },
				{ "title": "Schindlers List", "imageUrl": "https://picsum.photos/seed/schindlers-list" },
				{ "title": "12 Angry Men", "imageUrl": "https://picsum.photos/seed/12-angry-men" },
				{ "title": "The Return of the King", "imageUrl": "https://picsum.photos/seed/return-of-the-king" },
				{ "title": "Fight Club", "imageUrl": "https://picsum.photos/seed/fight-club" },
				{ "title": "Forrest Gump", "imageUrl": "https://picsum.photos/seed/forrest-gump" },
				{ "title": "The Fellowship of the Ring", "imageUrl": "https://picsum.photos/seed/fellowship-of-the-ring" },
				{ "title": "The Two Towers", "imageUrl": "https://picsum.photos/seed/the-two-towers" },
				{ "title": "Goodfellas", "imageUrl": "https://picsum.photos/seed/goodfellas" },
				{ "title": "The Matrix", "imageUrl": "https://picsum.photos/seed/the-matrix" },
				{ "title": "One Flew Over the Cuckoos Nest", "imageUrl": "https://picsum.photos/seed/one-flew-over" },
				{ "title": "Se7en", "imageUrl": "https://picsum.photos/seed/se7en" },
				{ "title": "City of God", "imageUrl": "https://picsum.photos/seed/city-of-god" },
				{ "title": "The Silence of the Lambs", "imageUrl": "https://picsum.photos/seed/silence-of-the-lambs" },
				{ "title": "Its a Wonderful Life", "imageUrl": "https://picsum.photos/seed/its-a-wonderful-life" },
				{ "title": "The Green Mile", "imageUrl": "https://picsum.photos/seed/the-green-mile" },
				{ "title": "Life Is Beautiful", "imageUrl": "https://picsum.photos/seed/life-is-beautiful" }
			]
		},
		{
			' "rowIndex": 2
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Action"
			}
			items: [
				{ "title": "John Wick", "imageUrl": "https://picsum.photos/seed/john-wick" },
				{ "title": "Mad Max Fury Road", "imageUrl": "https://picsum.photos/seed/mad-max-fury-road" },
				{ "title": "Gladiator", "imageUrl": "https://picsum.photos/seed/gladiator" },
				{ "title": "Die Hard", "imageUrl": "https://picsum.photos/seed/die-hard" },
				{ "title": "Casino Royale", "imageUrl": "https://picsum.photos/seed/casino-royale" },
				{ "title": "Skyfall", "imageUrl": "https://picsum.photos/seed/skyfall" },
				{ "title": "The Bourne Ultimatum", "imageUrl": "https://picsum.photos/seed/bourne-ultimatum" },
				{ "title": "The Raid Redemption", "imageUrl": "https://picsum.photos/seed/the-raid-redemption" },
				{ "title": "Logan", "imageUrl": "https://picsum.photos/seed/logan" },
				{ "title": "The Avengers", "imageUrl": "https://picsum.photos/seed/the-avengers" },
				{ "title": "Terminator 2 Judgment Day", "imageUrl": "https://picsum.photos/seed/terminator-2" },
				{ "title": "Oldboy", "imageUrl": "https://picsum.photos/seed/oldboy" },
				{ "title": "Atomic Blonde", "imageUrl": "https://picsum.photos/seed/atomic-blonde" },
				{ "title": "Heat", "imageUrl": "https://picsum.photos/seed/heat-movie" },
				{ "title": "Leon The Professional", "imageUrl": "https://picsum.photos/seed/leon-the-professional" },
				{ "title": "FaceOff", "imageUrl": "https://picsum.photos/seed/faceoff" },
				{ "title": "Taken", "imageUrl": "https://picsum.photos/seed/taken" },
				{ "title": "The Dark Knight Rises", "imageUrl": "https://picsum.photos/seed/dark-knight-rises" },
				{ "title": "Crouching Tiger Hidden Dragon", "imageUrl": "https://picsum.photos/seed/crouching-tiger-hidden-dragon" }
			]
		},
		{
			' "rowIndex": 3
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "Comedy"
			}
			items: [
				{ "title": "The Grand Budapest Hotel", "imageUrl": "https://picsum.photos/seed/grand-budapest-hotel" },
				{ "title": "Superbad", "imageUrl": "https://picsum.photos/seed/superbad" },
				{ "title": "Step Brothers", "imageUrl": "https://picsum.photos/seed/step-brothers" },
				{ "title": "Bridesmaids", "imageUrl": "https://picsum.photos/seed/bridesmaids" },
				{ "title": "The Hangover", "imageUrl": "https://picsum.photos/seed/the-hangover" },
				{ "title": "Anchorman The Legend of Ron Burgundy", "imageUrl": "https://picsum.photos/seed/anchorman" },
				{ "title": "Groundhog Day", "imageUrl": "https://picsum.photos/seed/groundhog-day" },
				{ "title": "Monty Python and the Holy Grail", "imageUrl": "https://picsum.photos/seed/monty-python-holy-grail" },
				{ "title": "Some Like It Hot", "imageUrl": "https://picsum.photos/seed/some-like-it-hot" },
				{ "title": "Mean Girls", "imageUrl": "https://picsum.photos/seed/mean-girls" },
				{ "title": "Airplane", "imageUrl": "https://picsum.photos/seed/airplane-movie" },
				{ "title": "Shaun of the Dead", "imageUrl": "https://picsum.photos/seed/shaun-of-the-dead" },
				{ "title": "Hot Fuzz", "imageUrl": "https://picsum.photos/seed/hot-fuzz" },
				{ "title": "Ghostbusters", "imageUrl": "https://picsum.photos/seed/ghostbusters" },
				{ "title": "The Big Lebowski", "imageUrl": "https://picsum.photos/seed/big-lebowski" },
				{ "title": "Ferris Buellers Day Off", "imageUrl": "https://picsum.photos/seed/ferris-buellers-day-off" },
				{ "title": "Mrs Doubtfire", "imageUrl": "https://picsum.photos/seed/mrs-doubtfire" },
				{ "title": "The 40 Year Old Virgin", "imageUrl": "https://picsum.photos/seed/40-year-old-virgin" },
				{ "title": "Tropic Thunder", "imageUrl": "https://picsum.photos/seed/tropic-thunder" },
				{ "title": "Borat", "imageUrl": "https://picsum.photos/seed/borat" }
			]
		},
		{
			' "rowIndex": 4
			"componentName": "GridItemRenderer"
			"header": {
				"componentName": "CustomRowHeader"
				"title": "New Releases"
			}
			items: [
				{ "title": "Oppenheimer", "imageUrl": "https://picsum.photos/seed/oppenheimer" },
				{ "title": "Barbie", "imageUrl": "https://picsum.photos/seed/barbie-movie" },
				{ "title": "Mission Impossible Dead Reckoning", "imageUrl": "https://picsum.photos/seed/mission-impossible-dead-reckoning" },
				{ "title": "Indiana Jones Dial of Destiny", "imageUrl": "https://picsum.photos/seed/indiana-jones-dial-of-destiny" },
				{ "title": "The Little Mermaid", "imageUrl": "https://picsum.photos/seed/the-little-mermaid" },
				{ "title": "John Wick Chapter 4", "imageUrl": "https://picsum.photos/seed/john-wick-chapter-4" },
				{ "title": "Spider-Man Across the Spider-Verse", "imageUrl": "https://picsum.photos/seed/spider-man-across-the-spider-verse" },
				{ "title": "The Super Mario Bros Movie", "imageUrl": "https://picsum.photos/seed/super-mario-bros-movie" },
				{ "title": "Everything Everywhere All At Once", "imageUrl": "https://picsum.photos/seed/everything-everywhere-all-at-once" },
				{ "title": "The Creator", "imageUrl": "https://picsum.photos/seed/the-creator" },
				{ "title": "Ant-Man and the Wasp Quantumania", "imageUrl": "https://picsum.photos/seed/ant-man-quantumania" },
				{ "title": "Shazam Fury of the Gods", "imageUrl": "https://picsum.photos/seed/shazam-fury-of-the-gods" },
				{ "title": "Creed III", "imageUrl": "https://picsum.photos/seed/creed-iii" },
				{ "title": "Haunted Mansion", "imageUrl": "https://picsum.photos/seed/haunted-mansion" },
				{ "title": "The Flash", "imageUrl": "https://picsum.photos/seed/the-flash" },
				{ "title": "Dune Part Two", "imageUrl": "https://picsum.photos/seed/dune-part-two" },
				{ "title": "Wonka", "imageUrl": "https://picsum.photos/seed/wonka-movie" },
				{ "title": "Napoleon", "imageUrl": "https://picsum.photos/seed/napoleon-movie" },
				{ "title": "Killers of the Flower Moon", "imageUrl": "https://picsum.photos/seed/killers-of-the-flower-moon" },
				{ "title": "Poor Things", "imageUrl": "https://picsum.photos/seed/poor-things" }
			]
		}
	]

	rows = [rows[0], rows[1], rows[3], rows[4],rows[0], rows[1], rows[3], rows[4], rows[0], rows[1], rows[3], rows[4], rows[0], rows[1], rows[3], rows[4], rows[0], rows[1], rows[3], rows[4]]

	' rows = [rows[0], rows[1]]

	' rows = [rows[0]]

	' Programmatically alternate every other item component to use GridItemRenderer2
	for each row in rows
		if row.items <> invalid then
			idx = 0
			for each item in row.items
				if (idx mod 2) = 1 then
					' item.componentName = "GridItemRenderer2"
				end if
				idx = idx + 1
			end for
		end if
	end for

	m.renderThreadQueue = createObject("roRenderThreadQueue")
	m.renderThreadQueue.postMessage(m.grid.contentSuppliedQueueId, rows)
end sub
