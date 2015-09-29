<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
	xmlns:xlink="http://www.w3.org/1999/xlink" 
	xmlns:local="http://www.loc.org/namespace"
	xmlns:mods="http://www.loc.gov/mods/v3"	
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:bf="http://bibframe.org/vocab/" 
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" 
	xmlns:madsrdf="http://www.loc.gov/mads/rdf/v1#" 
	xmlns:relators="http://id.loc.gov/vocabulary/relators/"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	exclude-result-prefixes="mods xlink" 
	xmlns:marc="http://www.loc.gov/MARC21/slim">
<!-- 
	NB: THIS UNAPPROVED DRAFT STYLESHEET – IT IS NOT APPROVED NORE IS IT INTENDED FOR DISTRIBUTION.
	Revision 1.00 - 2015/09/29

	
	This stylesheet transforms MODS records and collections of MODS records to BIBFRAME RDF/XML 
	based on the Library of Congress' MODS to BIBFRAME mapping <LINK> 

	assumptions and dependencies:
		+ uses doc('http://id.loc.gov/vocabulary/relators.madsrdf.rdf') for relator codes, to run with out 
		  internet access, download relators.madsrdf.rdf and change path accordingly. 
        + transform has been tested with Saxon PE 9.5.0.2 
        
	code by: 
        + Winona Salesky wsalesky@gmail.com 
	    
	[1] http://www.openarchives.org/OAI/openarchivesprotocol.html#MetadataNamespaces
	[2] http://www.loc.gov/standards/sru/record-schemas.html
	[3] http://id.loc.gov/vocabulary/relators/
	        
	        
	First pass - MODS to BIBFRAME	 
-->
	
	<xsl:output method="xml" indent="yes" encoding="UTF-8"/>
	<!-- Strip unnecessary whitespace -->
	<xsl:strip-space elements="*" />
	
	<!-- NOTE: check param construction -->
	<xsl:param name="uri-base" select="'http://bibframe.org/resources/'"/>
	
	<!-- Notes Using marc2bibframe as a model for bibframe generation -->
	<!-- Build RDF output -->
	<xsl:template match="/">
		<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
			<xsl:apply-templates select="//mods:mods"/>
		</rdf:RDF>
	</xsl:template>
	
	<!-- Variables used to create RDF URIs -->
	<!-- Local functions to build @rdf:resource and @rdf:about refs -->
	<xsl:function name="local:rdf-resource">
		<!-- Node passed to function -->
		<xsl:param name="node"/>
		<!-- Reference type used to build resource URI if empty use local element name -->
		<xsl:param name="ref-type"/>
		<!-- Build work id -->
		<xsl:variable name="id">
			<xsl:choose>
				<xsl:when test="$node/ancestor-or-self::mods:relatedItem">
					<xsl:choose>
						<xsl:when test="$node/ancestor-or-self::mods:relatedItem/mods:recordInfo/mods:recordIdentifier">
							<xsl:value-of select="$node/ancestor-or-self::mods:relatedItem/mods:recordInfo/mods:recordIdentifier/text()"/>
						</xsl:when>
						<xsl:when test="$node/ancestor-or-self::mods:relatedItem/mods:identifier[not(@invalid='yes')]">
							<xsl:value-of select="replace($node/ancestor-or-self::mods:relatedItem/mods:identifier[not(@invalid='yes')][1]/text(),' ','')"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:choose>
								<xsl:when test="$node/ancestor-or-self::mods:mods/mods:recordInfo/mods:recordIdentifier">
									<xsl:value-of select="$node/ancestor-or-self::mods:mods/mods:recordInfo/mods:recordIdentifier/text()"/>
								</xsl:when>
								<xsl:when test="$node/ancestor-or-self::mods:mods/mods:identifier[not(@invalid='yes')]">
									<xsl:value-of select="replace($node/ancestor-or-self::mods:mods/mods:identifier[not(@invalid='yes')][1]/text(),' ','')"/>
								</xsl:when>
								<xsl:otherwise>
									<xsl:value-of select="generate-id($node/ancestor-or-self::mods:mods)"/>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:when test="$node/ancestor-or-self::mods:mods/mods:recordInfo/mods:recordIdentifier">
					<xsl:value-of select="$node/ancestor-or-self::mods:mods/mods:recordInfo/mods:recordIdentifier/text()"/>
				</xsl:when>
				<xsl:when test="$node/ancestor-or-self::mods:mods/mods:identifier[not(@invalid='yes')]">
					<xsl:value-of select="replace($node/ancestor-or-self::mods:mods/mods:identifier[not(@invalid='yes')][1]/text(),' ','')"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="generate-id($node/ancestor-or-self::mods:mods)"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<!-- For title refs -->
		<xsl:variable name="titleType">
			<xsl:choose>
				<xsl:when test="$node/@type='abbreviated'"><xsl:text>abbreviatedTitle</xsl:text></xsl:when>
				<xsl:when test="$node/@type='alternative' and $node/@otherType='keyTitle'"><xsl:text>KeyTitle</xsl:text></xsl:when>
				<xsl:when test="$node/@type='alternative'"><xsl:text>titleVariation</xsl:text></xsl:when>
				<xsl:otherwise><xsl:text>title</xsl:text></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<!-- For relatedItems -->
		<xsl:variable name="ref-subType">
			<xsl:variable name="cap-title">
				<xsl:value-of select="concat(upper-case(substring($titleType,1,1)),substring($titleType,2))"/>
			</xsl:variable>
			<xsl:choose>
				<xsl:when test="$node/parent::mods:relatedItem">
					<xsl:value-of select="concat('relatedItem',$cap-title)"/>
				</xsl:when>
				<xsl:otherwise><xsl:value-of select="$titleType"/></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="modsChild" select="$node/ancestor-or-self::*[parent::mods:mods]"/>
		<!-- Pull it all together for URI -->
		<xsl:choose>
			<xsl:when test="$node/parent::mods:relatedItem">
				<xsl:value-of select="concat($uri-base,$id,$ref-type,count($modsChild/preceding-sibling::*) + 1,$ref-subType,count($node/preceding-sibling::*) +1)"/>
			</xsl:when>
			<xsl:when test="$ref-type='work'">
				<xsl:value-of select="concat($uri-base,$id)"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:choose>
					<xsl:when test="$ref-type !=''">
						<xsl:value-of select="concat($uri-base,$id,$ref-type,count($modsChild/preceding-sibling::*) +1)"/>
					</xsl:when>
					<xsl:when test="$node/parent::mods:mods">
						<xsl:value-of select="concat($uri-base,$id,local-name($node),count($modsChild/preceding-sibling::*) +1)"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="concat($uri-base,$id,local-name($node),count($modsChild/preceding-sibling::*) +1)"/>
					</xsl:otherwise>
				</xsl:choose>				
			</xsl:otherwise>
		</xsl:choose>
	</xsl:function>

	<!-- Pull in relator codes from http://id.loc.gov/vocabulary/relators.madsrdf.rdf -->
	<xsl:variable name="relator">
		<xsl:for-each select="doc('http://id.loc.gov/vocabulary/relators.madsrdf.rdf')//madsrdf:MADSScheme/madsrdf:hasTopMemberOfMADSScheme">
			<relator><xsl:value-of select="tokenize(@rdf:resource,'/')[last()]"/></relator>
		</xsl:for-each>
	</xsl:variable>
	
	<!-- Main MODS template builds BIBFRAME classes -->
	<xsl:template match="mods:mods">
		<xsl:call-template name="bibframe"/>
	</xsl:template>
	
	<!-- Builds bibframe wrappers used by mods:mods and mods:relatedItem -->
	<xsl:template name="bibframe">
		<!-- Calls BIBFRAME Work for each mods:title[@uniform] -->
		<xsl:call-template name="work"/>
		
		<!-- Calls BIBFRAME Instance -->
		<xsl:call-template name="instance"/>
		
		<!-- Calls BIBFRAME Annotation -->
		<xsl:call-template name="Annotation"/>
		
		<!-- Calls BIBFRAME HeldMaterial -->
		<xsl:call-template name="HeldMaterial"/>
		
		<!-- Calls BIBFRAME HeldItem -->
		<xsl:call-template name="HeldItem"/>
		
		<!-- Calls additional BIBFRAME Classes -->
		<xsl:apply-templates select="mods:titleInfo" mode="title-class"/>
		<xsl:apply-templates select="mods:name"/>
		<xsl:apply-templates select="mods:genre"/>
		<xsl:apply-templates select="mods:subject"/>
		<xsl:apply-templates select="mods:language"/>
		<!-- Called inside Annotation <xsl:apply-templates select="mods:abstract"/>-->
		<!--<xsl:apply-templates select="mods:tableOfContents"/>-->
		<xsl:apply-templates select="mods:relatedItem"/>
		<xsl:apply-templates select="mods:classification"/>
		<xsl:apply-templates select="mods:physicalDescription/mods:form"/>
	</xsl:template>
	
	<!-- Build BIBFRAME Work -->
	<xsl:template name="work">
		<bf:Work xmlns:bf="http://bibframe.org/vocab/" 
			xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" 
			xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
			xmlns:madsrdf="http://www.loc.gov/mads/rdf/v1#" 
			xmlns:relators="http://id.loc.gov/vocabulary/relators/">
			<!-- Title Authorized Access Point -->
			<xsl:attribute name="about" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
				<xsl:choose>
					<xsl:when test="self::mods:relatedItem"><xsl:value-of select="local:rdf-resource(.,'relatedItem')"/></xsl:when>
					<xsl:otherwise><xsl:value-of select="local:rdf-resource(.,'work')"/></xsl:otherwise>
				</xsl:choose>					
			</xsl:attribute>
			<!-- Add rdf:resource to bf:works with @valueURI, @xlink:href. Current use case is for mods:relatedItem -->
			<xsl:choose>
				<xsl:when test="self::*/@valueURI"><xsl:attribute name="about" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><xsl:value-of select="@valueURI"/></xsl:attribute></xsl:when>
				<xsl:when test="self::*/@xlink:href"><xsl:attribute name="about" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><xsl:value-of select="@xlink:href"/></xsl:attribute></xsl:when>
			</xsl:choose>
			
			<xsl:for-each select="mods:titleInfo[@type='uniform']|mods:titleInfo[not(@type)]">
				<!-- Type? -->
				<xsl:apply-templates select="mods:typeOfResource" mode="ref"/>
				<xsl:call-template name="authorizedAccessPoint"/>
				<!-- Title -->
				<xsl:apply-templates select="." mode="ref"/>
				<xsl:apply-templates select="."/>
			</xsl:for-each>	
			
			<!-- Names -->
			<xsl:apply-templates select="mods:name" mode="ref"/>
			
			<!-- Event --> 
			<xsl:apply-templates select="mods:originInfo/mods:dateCaptured" mode="ref"/>
			
			<!-- TargetAudience NOTE: should this be a ref? looks diff in little-house -->
			<xsl:apply-templates select="mods:targetAudience"/>
			
			<!-- Language -->
			<xsl:apply-templates select="mods:language" mode="property"/>
			
			<!-- Genre -->
			<xsl:apply-templates select="mods:genre" mode="ref"/>
			
			<!--NOTE: Note Lang
			note@type="language" - work - spreadsheet says WORK, xquery says Instance, for tolstoy rec Instance seems to make more sense
			-->
			<!-- Subjects -->
			<xsl:apply-templates select="mods:subject">
				<xsl:with-param name="mode" select="'ref'"/>
			</xsl:apply-templates>
			
			<!-- Related Items -->
			<xsl:apply-templates select="mods:relatedItem" mode="ref"/>
			
			<!-- Classification -->
			<xsl:apply-templates select="mods:classification" mode="ref"/>

			<!-- Thesis -->
			<xsl:apply-templates select="mods:note[@type='thesis']"/>
			
			<!-- Annotation -->
			<xsl:for-each select="mods:abstract">
				<bf:hasAnnotation rdf:resource="{concat(local:rdf-resource(.,'work'),'Annotation',count(preceding-sibling::*))}"/>
			</xsl:for-each>
		</bf:Work>
	</xsl:template>
	
	<!-- Build BIBFRAME Instance -->
	<xsl:template name="instance">
		<!-- Need to figure out how about numbers are generated -->
		<bf:Instance xmlns:bf="http://bibframe.org/vocab/" 
			xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" 
			xmlns:madsrdf="http://www.loc.gov/mads/rdf/v1#" 
			xmlns:relators="http://id.loc.gov/vocabulary/relators/">
			<xsl:attribute name="about" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
				<xsl:choose>
					<xsl:when test="self::mods:relatedItem"><xsl:value-of select="concat(local:rdf-resource(.,'relatedItem'),'instance',count(child::*))"/></xsl:when>
					<xsl:otherwise><xsl:value-of select="concat(local:rdf-resource(.,'work'),'instance',count(child::*))"/></xsl:otherwise>
				</xsl:choose>					
			</xsl:attribute>
			<xsl:apply-templates select="mods:typeOfResource" mode="ref"/>
			<xsl:apply-templates select="mods:titleInfo" mode="instance-ref"/>
			<xsl:apply-templates select="mods:titleInfo[not(@type='alternative') and not(@type='abbreviated') and not(@type='translated')]"/>
			<!--<xsl:apply-templates select="mods:titleInfo[not(@type)]"/>--> 
			<xsl:apply-templates select="mods:originInfo"/>
			<xsl:apply-templates select="mods:physicalDescription" mode="property"/>
			<xsl:apply-templates select="mods:tableOfContents" mode="property"/>
			<!-- Language Note-->
			<!-- Check, may only want a certian type of note? -->
			<xsl:apply-templates select="mods:note"/>
			<xsl:apply-templates select="mods:identifier"/>
			<xsl:apply-templates select="relatedItem[@type='otherFormat']"/>
			<!-- Language Note
			<xsl:apply-templates select="mods:note[@type='language']"/>-->
			<bf:instanceOf>
				<xsl:attribute name="resource" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
					<xsl:choose>
						<xsl:when test="self::mods:relatedItem"><xsl:value-of select="local:rdf-resource(.,'relatedItem')"/></xsl:when>
						<xsl:otherwise><xsl:value-of select="local:rdf-resource(.,'work')"/></xsl:otherwise>
					</xsl:choose>					
				</xsl:attribute>				
			</bf:instanceOf>

			<!-- Annotation -->
			<xsl:for-each select="mods:recordInfo | mods:tableOfContents[@xlink]">
				<bf:hasAnnotation rdf:resource="{concat(local:rdf-resource(.,'work'),'Annotation',count(preceding-sibling::*))}"/>
			</xsl:for-each>
		</bf:Instance>
	</xsl:template>
	
	<!-- Build BIBFRAME Annotation -->
	<xsl:template name="Annotation">
		<xsl:for-each select="mods:recordInfo | mods:abstract | mods:tableOfContents[@xlink]">
			<bf:Annotation xmlns:bf="http://bibframe.org/vocab/" 
				xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" 
				xmlns:madsrdf="http://www.loc.gov/mads/rdf/v1#" 
				xmlns:relators="http://id.loc.gov/vocabulary/relators/">
				<xsl:attribute name="about" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
					<xsl:choose>
						<xsl:when test="self::mods:relatedItem"><xsl:value-of select="concat(local:rdf-resource(.,'relatedItem'),'Annotation',count(child::*))"/></xsl:when>
						<xsl:otherwise><xsl:value-of select="concat(local:rdf-resource(.,'work'),'Annotation',count(preceding-sibling::*))"/></xsl:otherwise>
					</xsl:choose>					
				</xsl:attribute>
				<xsl:apply-templates select="."/>
				<bf:annotates>
					<xsl:attribute name="resource" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
						<xsl:choose>
							<xsl:when test="self::mods:relatedItem"><xsl:value-of select="local:rdf-resource(.,'relatedItem')"/></xsl:when>
							<xsl:otherwise><xsl:value-of select="local:rdf-resource(.,'work')"/></xsl:otherwise>
						</xsl:choose>					
					</xsl:attribute>	
				</bf:annotates>
			</bf:Annotation>
		</xsl:for-each>
	</xsl:template>
	
	<!-- Build BIBFRAME HeldItem -->
	<xsl:template name="HeldMaterial">
		<xsl:if test="mods:note[@type='restriction'] or mods:location/mods:physicalLocation or  mods:location/mods:url
			or mods:location/mods:holdingSimple or mods:location/mods:copyInformation/mods:subLocation
			or mods:location/mods:copyInformation/mods:electronicLocator or  mods:location/mods:copyInformation/mods:enumerationAndChronology
			or mods:accessCondition">
			<bf:HeldMaterial xmlns:bf="http://bibframe.org/vocab/" 
				xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" 
				xmlns:madsrdf="http://www.loc.gov/mads/rdf/v1#" 
				xmlns:relators="http://id.loc.gov/vocabulary/relators/" >
				<xsl:attribute name="about" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
					<xsl:choose>
						<xsl:when test="self::mods:relatedItem"><xsl:value-of select="concat(local:rdf-resource(.,'relatedItem'),'HeldMaterial',count(child::*))"/></xsl:when>
						<xsl:otherwise><xsl:value-of select="concat(local:rdf-resource(.,'work'),'HeldMaterial',count(child::*))"/></xsl:otherwise>
					</xsl:choose>					
				</xsl:attribute>
				<xsl:apply-templates select="mods:note[@type='restriction'] 
					| mods:location/mods:physicalLocation |  mods:location/mods:url
					| mods:location/mods:holdingSimple | mods:location/mods:copyInformation/mods:subLocation
					| mods:location/mods:copyInformation/mods:electronicLocator |  mods:location/mods:copyInformation/mods:enumerationAndChronology
					| mods:accessCondition"/>
				<bf:holdingFor rdf:resource="{concat(local:rdf-resource(.,'work'),'instance',count(child::*))}">
					<xsl:attribute name="resource" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
						<xsl:choose>
							<xsl:when test="self::mods:relatedItem"><xsl:value-of select="concat(local:rdf-resource(.,'relatedItem'),'instance',count(child::*))"/></xsl:when>
							<xsl:otherwise><xsl:value-of select="concat(local:rdf-resource(.,'work'),'instance',count(child::*))"/></xsl:otherwise>
						</xsl:choose>					
					</xsl:attribute>	
				</bf:holdingFor>
			</bf:HeldMaterial>
		</xsl:if>
	</xsl:template>
	
	<!-- Build BIBFRAME HeldItem -->
	<xsl:template name="HeldItem">
		<xsl:if test="descendant-or-self::mods:shelfLocator">
			<bf:HeldItem xmlns:bf="http://bibframe.org/vocab/" 
				xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" 
				xmlns:madsrdf="http://www.loc.gov/mads/rdf/v1#" 
				xmlns:relators="http://id.loc.gov/vocabulary/relators/" >
				<xsl:attribute name="about" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
					<xsl:choose>
						<xsl:when test="self::mods:relatedItem"><xsl:value-of select="concat(local:rdf-resource(.,'relatedItem'),'HeldItem',count(child::*))"/></xsl:when>
						<xsl:otherwise><xsl:value-of select="concat(local:rdf-resource(.,'work'),'HeldItem',count(child::*))"/></xsl:otherwise>
					</xsl:choose>					
				</xsl:attribute>
				<xsl:apply-templates select="descendant-or-self::mods:shelfLocator"/>
				<bf:holdingFor rdf:resource="{concat(local:rdf-resource(.,'work'),'instance',count(child::*))}">
					<xsl:attribute name="resource" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
						<xsl:choose>
							<xsl:when test="self::mods:relatedItem"><xsl:value-of select="concat(local:rdf-resource(.,'relatedItem'),'instance',count(child::*))"/></xsl:when>
							<xsl:otherwise><xsl:value-of select="concat(local:rdf-resource(.,'work'),'instance',count(child::*))"/></xsl:otherwise>
						</xsl:choose>					
					</xsl:attribute>	
				</bf:holdingFor>
			</bf:HeldItem>
		</xsl:if>
	</xsl:template>	
	
	<!-- Authorized access point @param nodes used for authorized acces points  -->
	<xsl:template name="authorizedAccessPoint">
		<bf:authorizedAccessPoint>
			<xsl:value-of select="normalize-space(string-join(node(),' '))"/>
		</bf:authorizedAccessPoint>
		<!-- NOTE question about where this should be present-->
		<bf:authorizedAccessPoint xml:lang="x-bf-hash"><xsl:value-of select="replace(lower-case(normalize-space(string-join(node(),''))),'([.,;:\[\]\s&quot;''])\s*','')"/></bf:authorizedAccessPoint>
	</xsl:template>
	
	<!-- TitleInfo for Work -->
	<xsl:template match="mods:titleInfo" mode="ref">
		<!--NOTE:  Add a choose statement with more options (see below) -->
		<!-- For handling mods:relatedItem titles -->
		<xsl:variable name="type">
			<xsl:choose>
				<xsl:when test="@type='abbreviated'"><xsl:text>abbreviatedTitle</xsl:text></xsl:when>
				<xsl:when test="@type='alternative' and @otherType='keyTitle'"><xsl:text>KeyTitle</xsl:text></xsl:when>
				<xsl:when test="@type='alternative'"><xsl:text>titleVariation</xsl:text></xsl:when>
				<xsl:otherwise><xsl:text>title</xsl:text></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="ref-type">
			<xsl:variable name="title-type">
				<xsl:value-of select="concat(upper-case(substring($type,1,1)),substring($type,2))"/>
			</xsl:variable>
			<xsl:choose>
				<xsl:when test="parent::mods:relatedItem"><xsl:text>relatedItem</xsl:text></xsl:when>
				<xsl:otherwise><xsl:value-of select="$type"/></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<bf:workTitle rdf:resource="{local:rdf-resource(.,$ref-type)}"/>
	</xsl:template>
	
	<!-- TitleInfo for Instances -->
	<xsl:template match="mods:titleInfo" mode="instance-ref">
		<xsl:variable name="type">
			<xsl:choose>
				<xsl:when test="@type='abbreviated'"><xsl:text>abbreviatedTitle</xsl:text></xsl:when>
				<xsl:when test="@type='alternative' and @otherType='keyTitle'"><xsl:text>KeyTitle</xsl:text></xsl:when>
				<xsl:when test="@type='alternative'"><xsl:text>titleVariation</xsl:text></xsl:when>
				<xsl:otherwise><xsl:text>title</xsl:text></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="ref-type">
			<xsl:variable name="title-type">
				<xsl:value-of select="concat(upper-case(substring($type,1,1)),substring($type,2))"/>
			</xsl:variable>
			<xsl:choose>
				<xsl:when test="parent::mods:relatedItem"><xsl:text>relatedItem</xsl:text></xsl:when>
				<xsl:otherwise><xsl:value-of select="$type"/></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="@type='abbreviated'">
				<bf:abbreviatedTitle rdf:resource="{local:rdf-resource(.,$ref-type)}"/>
			</xsl:when>
			<xsl:when test="@type='alternative' and @otherType='keyTitle'">
				<bf:KeyTitle rdf:resource="{local:rdf-resource(.,$ref-type)}"/>
			</xsl:when>
			<xsl:when test="@type='alternative'">
				<bf:titleVariation rdf:resource="{local:rdf-resource(.,$ref-type)}"/>
			</xsl:when>
			<xsl:otherwise>
				<bf:instanceTitle rdf:resource="{local:rdf-resource(.,$ref-type)}"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>	
	
	<xsl:template match="mods:titleInfo">
		<bf:title><xsl:value-of select="string-join(child::*,' ')"/></bf:title>
		<bf:title xml:lang="x-bf-sort"><xsl:value-of select="string-join(child::*[not(self::mods:nonSort)],' ')"/></bf:title>
	</xsl:template>
	
	<!--NOTE:  Looks like it should be keyTitle or TitleVariation, only question is where does it appear? in a new bf:title? or same -->
	<xsl:template match="mods:titleInfo" mode="title-class">
		<xsl:variable name="type">
			<xsl:choose>
				<xsl:when test="@type='abbreviated'"><xsl:text>abbreviatedTitle</xsl:text></xsl:when>
				<xsl:when test="@type='alternative' and @otherType='keyTitle'"><xsl:text>KeyTitle</xsl:text></xsl:when>
				<xsl:when test="@type='alternative'"><xsl:text>titleVariation</xsl:text></xsl:when>
				<xsl:otherwise><xsl:text>title</xsl:text></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<!-- For handling mods:relatedItem titles -->
		<xsl:variable name="ref-type">
			<xsl:variable name="title-type">
				<xsl:value-of select="concat(upper-case(substring($type,1,1)),substring($type,2))"/>
			</xsl:variable>
			<xsl:choose>
				<xsl:when test="parent::mods:relatedItem"><xsl:text>relatedItem</xsl:text></xsl:when>
				<xsl:otherwise><xsl:value-of select="$type"/></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<bf:Title rdf:about="{local:rdf-resource(.,$ref-type)}">
			<xsl:apply-templates select="child::*[not(self::mods:nonSort)]"/>
		</bf:Title>
	</xsl:template>
	
	<!-- Title subelements -->
	<!-- NOTE: blank templates leave ugly spaces in output -->
	<xsl:template match="mods:nonSort"/>
	<xsl:template match="mods:title">
		<!--
			NOTE: Unclear
			nonsort characters are chopped and the type is x-bf-sortable; titles retain nonsort characters  
		-->
		
		<bf:titleValue><xsl:if test="preceding-sibling::mods:nonSort"><xsl:value-of select="concat(preceding-sibling::mods:nonSort,' ')"/></xsl:if><xsl:value-of select="."/></bf:titleValue>
	</xsl:template>
	<xsl:template match="mods:subTitle">
		<bf:subtitle><xsl:apply-templates/></bf:subtitle>
	</xsl:template>
	<xsl:template match="mods:partNumber">
		<bf:partNumber><xsl:apply-templates/></bf:partNumber>
	</xsl:template>
	<xsl:template match="mods:partName">
		<bf:partTitle><xsl:apply-templates/></bf:partTitle>
	</xsl:template>
		
	<!-- Name elements and subelements -->
	<xsl:template match="mods:name" mode="ref">
		<xsl:variable name="type">
			<xsl:choose>
				<xsl:when test="@type='family'">family</xsl:when>
				<xsl:when test="@type='personal'">person</xsl:when>
				<xsl:when test="@type='conference'">meeting</xsl:when>
				<xsl:when test=".[@type='corporate'] | .[@type='corporate' and .[mods:roleTerm[@type='code'] = 'dgg']]">organization</xsl:when>
				<xsl:otherwise>agent</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="@usage='primary'">
				<bf:creator rdf:resource="{local:rdf-resource(.,$type)}"/>
			</xsl:when>
			<!-- If match relator code use relator else use bf:contributor -->
			<xsl:when test="$relator/relator/text() = mods:role/mods:roleTerm[@authority='marcrelator'][@type='code']/text()">
				<xsl:element name="relators:{mods:role/mods:roleTerm[@type='code' and @authority='marcrelator']}" namespace="http://id.loc.gov/vocabulary/relators/" inherit-namespaces="no">
					<xsl:attribute name="rdf:resource" namespace="http://www.w3.org/2000/01/rdf-schema#" select="local:rdf-resource(.,$type)"/>
				</xsl:element>
			</xsl:when>
			<xsl:otherwise>
				<bf:contributor rdf:resource="{local:rdf-resource(.,$type)}"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<!-- NOTE: come back to this, xquery gets authority # somehow-->
	<!--
	<xsl:when test="mods:role/mods:roleTerm[@type='code']">

		<xsl:variable name="relator-name" select="mods:role/mods:roleTerm[@type='code']/text()"/>
		<xsl:element name="{$relator-name}" namespace="http://id.loc.gov/vocabulary/relators/">
			<xsl:attribute name="resource" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#" select="concat(local:rdf-about(../mods:recordInfo/mods:recordIdentifier[1]),$type,count(preceding-sibling::*)+1)"/>
		</xsl:element>
	</xsl:when>-->
	
	<!-- Name elements and subelements -->
	<xsl:template match="mods:name">
		<xsl:variable name="type">
			<xsl:choose>
				<xsl:when test="@type='family'">family</xsl:when>
				<xsl:when test="@type='personal'">person</xsl:when>
				<xsl:when test="@type='conference'">meeting</xsl:when>
				<xsl:when test=".[@type='corporate'] | .[@type='corporate' and .[mods:roleTerm[@type='code'] = 'dgg']]">organization</xsl:when>
				<xsl:otherwise>agent</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="label">
			<xsl:choose>
				<xsl:when test="child::mods:namePart">
					<xsl:choose>
						<xsl:when test="child::mods:namePart[@type]">
							<xsl:for-each select="child::mods:namePart">
								<xsl:apply-templates/>
								<xsl:choose>
									<xsl:when test="position() != last() and not(matches(.,'^.*[\.:,; ]$'))">
										<xsl:text>, </xsl:text>
									</xsl:when>
									<xsl:when test="position() = last() and not(matches(.,'^.*[\.:,; ]$'))">
										<!--<xsl:text>.</xsl:text>-->
									</xsl:when>
									<xsl:otherwise><xsl:text> </xsl:text></xsl:otherwise>
								</xsl:choose>
							</xsl:for-each>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="string-join(child::mods:namePart,' ')"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="string-join(child::mods:displayForm,' ')"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="@type='family'">
				<bf:Family rdf:about="{local:rdf-resource(.,$type)}">
					<bf:label><xsl:value-of select="$label"/></bf:label>
					<bf:authorizedAccessPoint><xsl:value-of select="$label"/></bf:authorizedAccessPoint>
					<xsl:call-template name="hasAuthority"/>
				</bf:Family>
			</xsl:when>
			<xsl:when test="@type='personal'">
				<bf:Person rdf:about="{local:rdf-resource(.,$type)}">
					<bf:label><xsl:value-of select="$label"/></bf:label>
					<bf:authorizedAccessPoint><xsl:value-of select="$label"/></bf:authorizedAccessPoint>
					<xsl:call-template name="hasAuthority"/>
				</bf:Person>
			</xsl:when>
			<xsl:when test="@type='conference'">
				<bf:Meeting rdf:about="{local:rdf-resource(.,$type)}">
					<bf:label><xsl:value-of select="$label"/></bf:label>
					<bf:authorizedAccessPoint><xsl:value-of select="$label"/></bf:authorizedAccessPoint>
					<xsl:call-template name="hasAuthority"/>
				</bf:Meeting>
			</xsl:when>
			<xsl:when test=".[@type='corporate'] | .[@type='corporate' and .[mods:roleTerm[@type='code'] = 'dgg']]">
				<bf:Organization rdf:about="{local:rdf-resource(.,$type)}">
					<bf:label><xsl:value-of select="$label"/></bf:label>
					<bf:authorizedAccessPoint><xsl:value-of select="$label"/></bf:authorizedAccessPoint>
					<xsl:call-template name="hasAuthority"/>
				</bf:Organization>
			</xsl:when>
			<xsl:otherwise>
				<bf:Agent rdf:about="{local:rdf-resource(.,$type)}">
					<bf:label><xsl:value-of select="$label"/></bf:label>
					<bf:authorizedAccessPoint><xsl:value-of select="$label"/></bf:authorizedAccessPoint>
					<xsl:call-template name="hasAuthority"/>
				</bf:Agent>
			</xsl:otherwise>
		</xsl:choose>		
	</xsl:template>
	
	<!-- Builds AuthoritySource and hasAuthority if indicated used by mods:name and mods:subject-->
	<xsl:template name="hasAuthority">
		<!--
		@authority = <bf:authoritySource>lcsh</bf:authoritySource><bf:hasAuthority/>
		@authorityURI = <bf:authoritySource rdf:resource="value of authorityURI"/><bf:hasAuthority/>
		@valueURI = <bf:hasAuthority rdf:resource="{./@valueURI}"/>
		@xlink = <bf:hasAuthority></bf:hasAuthority>
		-->
		<xsl:if test="@authority">
			<bf:authoritySource><xsl:value-of select="@authority"/></bf:authoritySource>
		</xsl:if>
		<xsl:if test="@authorityURI">
			<bf:authoritySource rdf:resource="{@authorityURI}"/>
		</xsl:if>
		<xsl:if test="@valueURI or @xlink:href or @authorityURI or @authority">
			<!-- NOTE : Too slow to be usable, reconfigure and try again. 
			<xsl:variable name="auth-resource">
				<xsl:variable name="auth-lookup-string" select="lower-case(string-join(mods:persName,' '))"/>	
				<xsl:value-of select="string(doc(concat('http://id.loc.gov/authorities/label/',$auth-lookup-string))//*:link[@rel='alternate'][@type='application/rdf+xml']/@href)"/>
			</xsl:variable>
			-->
			<bf:hasAuthority>
				<xsl:choose>
					<xsl:when test="@valueURI">
						<xsl:attribute name="rdf:resource"><xsl:value-of select="@valueURI"/></xsl:attribute>
					</xsl:when>
					<!--<xsl:when test="@authority and $auth-resource != ''"><xsl:attribute name="rdf:resource"><xsl:value-of select="$auth-resource"/></xsl:attribute></xsl:when>-->
					<xsl:otherwise>
						<madsrdf:Authority>
							<madsrdf:authoritativeLabel>
								<xsl:choose>
									<xsl:when test="self::mods:subject">
										<xsl:value-of select="string-join(child::*,'--')"/>
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="string-join(child::*,' ')"/>									
									</xsl:otherwise>
								</xsl:choose>
							</madsrdf:authoritativeLabel>
						</madsrdf:Authority>						
					</xsl:otherwise>
				</xsl:choose>
			</bf:hasAuthority>
		</xsl:if>
	</xsl:template>

	<!-- Type of Resource -->
	<xsl:template match="mods:typeOfResource" mode="ref">
		<xsl:variable name="type">
			<xsl:choose>
				<xsl:when test="./@collection">Collection</xsl:when>
				<xsl:when test="./@manuscript">Manuscript</xsl:when>
				<xsl:when test=". = 'text'">Text</xsl:when>
				<xsl:when test=". = 'cartographic'">Cartography</xsl:when>
				<xsl:when test=". = 'notated music'">NotatedMusic</xsl:when>
				<xsl:when test=". = 'sound recording-musical'">Audio</xsl:when>
				<xsl:when test=". = 'sound recording-nonmusical'">Audio</xsl:when>
				<xsl:when test=". = 'sound recording'">Audio</xsl:when>
				<xsl:when test=". = 'still image'">StillImage</xsl:when>
				<xsl:when test=". = 'moving image'">MovingImage</xsl:when>
				<xsl:when test=". = 'three dimensional object'">ThreeDimensionalObject</xsl:when>
				<!-- dataset or Multimedia?? -->
				<xsl:when test=". = 'software, multimedia'">Multimedia</xsl:when>
				<xsl:when test=". = 'mixed material'">MixedMaterial</xsl:when>
			</xsl:choose>
		</xsl:variable>
		<xsl:element name="rdf:type">
			<xsl:attribute name="rdf:resource">
				<xsl:value-of select="concat('http://bibframe.org/vocab/',$type)"/>
			</xsl:attribute>
		</xsl:element>
	</xsl:template>
	
	<!-- Genre / Form -->
	<xsl:template match="mods:genre" mode="ref">
<!--		use genre if string or from MARCGT; 
			categoryValue if necessary to give 
			authority + categoryType=genre; <mods:genre> with 
			authority aat should be mapped into bf:genre-->
		<xsl:choose>
			<xsl:when test="@authority = ('marcgt', 'aat')">
				<bf:genre rdf:resource="{local:rdf-resource(.,'genre')}"/>
			</xsl:when>
			<xsl:otherwise>
				<bf:contentCategory  rdf:resource="{local:rdf-resource(.,'genre')}"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<xsl:template match="mods:genre | mods:physicalDescription/mods:form">
		<xsl:choose>
			<xsl:when test="@authority = 'aat'">
				<bf:Category rdf:about="{local:rdf-resource(.,'genre')}">
					<bf:categorySource><xsl:value-of select="@authority"></xsl:value-of></bf:categorySource>
					<bf:categoryType>genre</bf:categoryType>
					<bf:categoryValue><xsl:value-of select="."/></bf:categoryValue>
				</bf:Category>
			</xsl:when>
			<xsl:otherwise>
				<bf:Category rdf:about="{local:rdf-resource(.,'genre')}">
					<xsl:choose>
						<xsl:when test="@type or @authority">
							<bf:categorySource><xsl:value-of select="@authority"></xsl:value-of></bf:categorySource>
							<xsl:choose>
								<xsl:when test="@type='carrier' or @authority = 'rdacarrier' or @authority='rdamedia'">
									<bf:carrierCategory><xsl:value-of select="."/></bf:carrierCategory>
								</xsl:when>
								<xsl:otherwise>
									<bf:categoryType><xsl:value-of select="."/></bf:categoryType>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:when>
						<xsl:otherwise>
							<bf:format><xsl:value-of select="."/></bf:format>
						</xsl:otherwise>
					</xsl:choose>
					<bf:categoryValue><xsl:value-of select="."/></bf:categoryValue>
				</bf:Category>
			</xsl:otherwise>
		</xsl:choose>
		
	</xsl:template>
	
	<!-- OriginInfo -->
	<xsl:template match="mods:originInfo">
		<xsl:choose>
			<xsl:when test="@eventType">
				<xsl:choose>
					<xsl:when test="@eventType='distribution'">
						<bf:distribution>
							<bf:Provider>
								<bf:providerRole><xsl:value-of select="@eventType"/></bf:providerRole>
								<xsl:apply-templates select="mods:place | mods:publisher | mods:dateIssued | mods:dateCreated | mods:dateOther | mods:copyrightDate" mode="provider"/>
							</bf:Provider>
						</bf:distribution>
					</xsl:when>
					<xsl:when test="@eventType='manufacture'">
						<bf:manufacture>
							<bf:Provider>
								<bf:providerRole><xsl:value-of select="@eventType"/></bf:providerRole>
								<xsl:apply-templates select="mods:place | mods:publisher | mods:dateIssued | mods:dateCreated | mods:dateOther | mods:copyrightDate" mode="provider"/>
							</bf:Provider>
						</bf:manufacture>
					</xsl:when>
					<xsl:when test="@eventType='production'">
						<bf:production>
							<bf:Provider>
								<bf:providerRole><xsl:value-of select="@eventType"/></bf:providerRole>
								<xsl:apply-templates select="mods:place | mods:publisher | mods:dateIssued | mods:dateCreated | mods:dateOther | mods:copyrightDate" mode="provider"/>
							</bf:Provider>
						</bf:production>
					</xsl:when>
					<xsl:when test="@eventType='publication'">
						<bf:publication>
							<bf:Provider>
								<bf:providerRole><xsl:value-of select="@eventType"/></bf:providerRole>
								<xsl:apply-templates select="mods:place | mods:publisher | mods:dateIssued | mods:dateCreated | mods:dateOther | mods:copyrightDate" mode="provider"/>
							</bf:Provider>
						</bf:publication>
					</xsl:when>
					<xsl:otherwise>
						<bf:publication>
							<bf:Provider>
								<xsl:apply-templates select="mods:place | mods:publisher | mods:dateIssued | mods:dateCreated | mods:dateOther | mods:copyrightDate" mode="provider"/>
							</bf:Provider>	
						</bf:publication>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<bf:publication>
					<bf:Provider>
						<xsl:apply-templates select="mods:place | mods:publisher | mods:dateIssued | mods:dateCreated | mods:dateOther | mods:copyrightDate" mode="provider"/>
					</bf:Provider>	
				</bf:publication>
				<!-- Removed in response to issue #1 - to many legacy records without @eventType
				<bf:providerStatement>
					<xsl:variable name="provider-string">
						<xsl:if test="mods:place/mods:placeTerm[@type='text'] or mods:place/mods:placeTerm[not(@type)]">
							<xsl:value-of select="mods:place/mods:placeTerm[@type='text'] | mods:place/mods:placeTerm[not(@type)]"/>
						</xsl:if>
						<xsl:if test="(mods:place/mods:placeTerm[@type='text'] or mods:place/mods:placeTerm[not(@type)]) and mods:publisher">
							<xsl:text> : </xsl:text>
						</xsl:if>
						<xsl:apply-templates select="mods:publisher"/>
						<xsl:if test="(mods:publisher or mods:place/mods:placeTerm[@type='text'] or mods:place/mods:placeTerm[not(@type)]) and (mods:dateIssued or mods:dateCreated or mods:dateOther or  mods:copyrightDate)">
							<xsl:text>, </xsl:text>
						</xsl:if>
						<xsl:apply-templates select="mods:dateIssued | mods:dateCreated | mods:dateOther | mods:copyrightDate"/>						
					</xsl:variable>
					<xsl:value-of select="normalize-space($provider-string)"/>
				</bf:providerStatement>
				-->
			</xsl:otherwise>
		</xsl:choose>

		<xsl:apply-templates select="mods:issuance | mods:edition | mods:frequency"/>
	</xsl:template>
	
	<!-- Origin info sub-elements, build provider class -->
	<xsl:template match="mods:place" mode="provider">
		<xsl:if test=".!=''">
			<bf:providerPlace>
				<bf:Place>
					<xsl:for-each select="mods:placeTerm">
						<xsl:call-template name="hasAuthority"/>
						<xsl:choose>
							<xsl:when test="@type='text' or @authority='iso3166'">
								<bf:label><xsl:value-of select="."/></bf:label>
							</xsl:when>
							<xsl:when test="@type='code' or @valueURI">
								<bf:Identifier>
									<bf:identifierValue><xsl:value-of select="."/></bf:identifierValue>
									<xsl:if test="@authority">
										<bf:identifierScheme rdf:resource="{@authority}"/>	
									</xsl:if>
								</bf:Identifier>
							</xsl:when>
						</xsl:choose>
					</xsl:for-each>	
				</bf:Place>
			</bf:providerPlace>
		</xsl:if>
	</xsl:template>
	<xsl:template match="mods:publisher" mode="provider">
		<xsl:if test=".!=''">
			<bf:providerName>
				<bf:Organization>
					<bf:label><xsl:value-of select="."/></bf:label>
				</bf:Organization>
			</bf:providerName>
		</xsl:if>
	</xsl:template>
	<xsl:template match="mods:dateIssued | mods:dateCreated | mods:dateOther" mode="provider">
		<xsl:if test=".!=''">
			<bf:providerDate><xsl:apply-templates/></bf:providerDate>
		</xsl:if>
	</xsl:template>
	<xsl:template match="mods:dateIssued | mods:dateCreated | mods:dateOther">
		<xsl:if test=". != ''">
			<xsl:choose>
				<xsl:when test="self::*[@point='start']">
					<xsl:value-of select="concat(.,'-')"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="."></xsl:value-of>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</xsl:template>
	<xsl:template match="mods:copyrightDate" mode="provider">
		<xsl:if test=".!=''">
			<bf:copyrightDate><xsl:apply-templates/></bf:copyrightDate>
		</xsl:if>
	</xsl:template>
	
	<!-- Events -->
	<xsl:template match="mods:dateCaptured" mode="ref">
		<bf:eventDate>
			<xsl:attribute name="rdf:resource">
				<xsl:value-of select="local:rdf-resource(.,'event')"/>
			</xsl:attribute>
		</bf:eventDate>
	</xsl:template>
	<xsl:template match="mods:dateCaptured">
		<bf:eventDate><xsl:apply-templates/></bf:eventDate>
	</xsl:template>
	
	<!-- General Instance templates (from mods:originInfo) -->
	<xsl:template match="mods:edition">
		<bf:edition><xsl:apply-templates/></bf:edition>
	</xsl:template>
	<xsl:template match="mods:issuance">
		<bf:modeOfIssuance><xsl:value-of select="normalize-space(.)"/></bf:modeOfIssuance>
		<!--
		<xsl:choose>
			<xsl:when test=".='continuing'">
				<bf:modeOfIssuance><xsl:apply-templates/></bf:modeOfIssuance>
			</xsl:when>
			<xsl:when test=".='monographic'">
				<bf:MultipartMonograph><xsl:apply-templates/></bf:MultipartMonograph>
			</xsl:when>
			<xsl:when test=".='single unit'">
				<bf:Monograph><xsl:apply-templates/></bf:Monograph>
			</xsl:when>
			<xsl:when test=".='multipart monograph'">
				<bf:MultipartMonograph><xsl:apply-templates/></bf:MultipartMonograph>
			</xsl:when>
			<xsl:when test=".='serial'">
				<bf:Serial><xsl:apply-templates/></bf:Serial>
			</xsl:when>
			<xsl:when test=".='integrating resource'">
				<bf:Integrating><xsl:apply-templates/></bf:Integrating>
			</xsl:when>
			<xsl:otherwise>
				<bf:modeOfIssuance><xsl:apply-templates/></bf:modeOfIssuance>				
			</xsl:otherwise>
		</xsl:choose>
		-->
	</xsl:template>
	<xsl:template match="mods:frequency">
		<bf:frequency><xsl:apply-templates/></bf:frequency>
	</xsl:template>
	
	<!-- Language -->
	<xsl:template match="mods:language" mode="property">
		<xsl:choose>
			<xsl:when test="@objectPart">
				<bf:language rdf:resource="{concat('http://id.loc.gov/vocabulary/languages/',mods:languageTerm/text())}"/>
			</xsl:when>
			<xsl:otherwise>
				<bf:language>
					<bf:Language>
						<xsl:apply-templates select="mods:languageTerm"/>
						<xsl:if test="mods:scriptTerm">
							<bf:notation><xsl:value-of select="mods:scriptTerm"/></bf:notation>
						</xsl:if>
					</bf:Language>
				</bf:language>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<xsl:template match="mods:language[@objectPart]">
		<bf:Language rdf:about="{local:rdf-resource(.,'languages')}">
			<bf:resourcePart><xsl:value-of select="string(@objectPart)"/></bf:resourcePart>
			<xsl:if test="mods:languageTerm[@valueURI]">
				<bf:languageOfPartUri rdf:resource="{@valueURI}"/>				
			</xsl:if>
			<!-- NOTE still have questions about this-->
			<xsl:apply-templates select="mods:languageTerm"/>
			<!--
			<bf:languageOfPartUri rdf:resource="http://id.loc.gov/vocabulary/languages/rus"/>
			-->
		</bf:Language>
	</xsl:template>
	<xsl:template match="mods:language">
		<bf:Language rdf:about="{local:rdf-resource(.,'languages')}">
			<xsl:apply-templates select="mods:languageTerm"/>
			<xsl:if test="mods:scriptTerm">
				<bf:notation><xsl:value-of select="mods:scriptTerm"/></bf:notation>
			</xsl:if>
		</bf:Language>
	</xsl:template>
	<xsl:template match="mods:languageTerm">
		<bf:language>
			<xsl:choose>
				<xsl:when test="@valueURI">
					<xsl:attribute name="rdf:resource"><xsl:value-of select="@valueURI"/></xsl:attribute>
				</xsl:when>
				<xsl:when test="@type='code'">
					<xsl:attribute name="rdf:resource"><xsl:value-of select="concat('http://id.loc.gov/vocabulary/languages/',.)"/></xsl:attribute>
				</xsl:when>
				<!-- If no code, output value of element -->
				<xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
			</xsl:choose>
		</bf:language>
		<xsl:if test="@authority">
			<bf:languageSource><xsl:value-of select="@authority"/></bf:languageSource>	
		</xsl:if>
	</xsl:template>
	
	<!-- Physical Description -->
	<xsl:template match="mods:physicalDescription" mode="property">
		<xsl:apply-templates mode="property"/>
	</xsl:template>
	<xsl:template match="mods:physicalDescription/mods:form" mode="property">
		<xsl:choose>
			<xsl:when test="@authority='aat'">
				<!-- NOTE: Testing -->
				<bf:genre rdf:resource="{local:rdf-resource(.,'genre')}"/>
			</xsl:when>
			<xsl:when test="@valueURI">
				<!-- NOTE: Testing -->
				<bf:carrierCategory rdf:resource="{@valueURI}"/>
			</xsl:when>
			<xsl:otherwise>
				<bf:carrierCategory rdf:resource="{local:rdf-resource(.,'genre')}"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template match="mods:physicalDescription/mods:reformattingQuality" mode="property">
		<bf:note><xsl:value-of select="concat('Reformatting quality: ',.)"/></bf:note>
	</xsl:template>
	<xsl:template match="mods:physicalDescription/mods:internetMediaType" mode="property">
		<!-- Instruction: Prepend value: "Internet media type:" or use PREMIS namespace -->
		<bf:format><xsl:value-of select="concat('Internet media type: ',.)"/></bf:format>
	</xsl:template>
	<xsl:template match="mods:physicalDescription/mods:extent" mode="property">
		<bf:extent><xsl:value-of select="."/></bf:extent>
	</xsl:template>
	<xsl:template match="mods:physicalDescription/mods:digitalOrigin" mode="property">
		<!-- Instruction: Prepend value: Digital origin:-->
		<bf:note><xsl:value-of select="concat('Digital origin: ',.)"/></bf:note>
	</xsl:template>
	<xsl:template match="mods:physicalDescription/mods:note[@type='physical details']" mode="property">
		<bf:extent><xsl:value-of select="."/></bf:extent>
	</xsl:template>
	<xsl:template match="mods:physicalDescription/mods:note[@type='organization']" mode="property">
		<!-- NOTE, this may be more complicated, check -->
		<bf:arrangement><xsl:value-of select="."/></bf:arrangement>
	</xsl:template>
	<xsl:template match="mods:physicalDescription/mods:note" mode="property">
		<bf:note><xsl:value-of select="."/></bf:note>
	</xsl:template>
	
	<xsl:template match="mods:abstract">
		<xsl:choose>
			<xsl:when test="@type = 'review' and @xlink:href">
				<bf:Review rdf:about="{local:rdf-resource(.,'review')}">
					<xsl:if test="text()">
						<bf:label><xsl:value-of select="."/></bf:label>
					</xsl:if>
					<xsl:if test="@xlink:href">
						<bf:review rdf:resource="{@xlink}"></bf:review>
					</xsl:if>
					<bf:reviewOf rdf:resource="{local:rdf-resource(.,'work')}"/>
				</bf:Review>
			</xsl:when>
			<xsl:otherwise>
				<bf:Summary rdf:about="{local:rdf-resource(.,'summary')}">
					<rdf:type rdf:resource="http://bibframe.org/vocab/Summary"/>
					<bf:label><xsl:apply-templates select="text()"/></bf:label>
					<xsl:if test="@xlink:href">
						<bf:summary rdf:resource="{@xlink:href}"/>	
					</xsl:if>
					<bf:summaryOf rdf:resource="{local:rdf-resource(.,'work')}"/>
				</bf:Summary>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<!-- Table of Contents -->
	<xsl:template match="mods:tableOfContents" mode="property">
		<xsl:choose>
			<xsl:when test="@xlink:href">	
				<bf:tableOfContents bf:about="{@xlink:href}"/>
			</xsl:when>
			<xsl:otherwise>
				<bf:contentsNote><xsl:value-of select="normalize-space(.)"/></bf:contentsNote>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<xsl:template match="mods:tableOfContents">
		<xsl:if test="mods:tableOfContents[@type='Incomplete contents'] or mods:tableOfContents[@type='Partial contents'] or mods:tableOfContents[@type='Contents']">
			<bf:TableOfContents rdf:about="{local:rdf-resource(.,'tableOfContents')}">
				<bf:label><xsl:apply-templates/></bf:label>
				<bf:tableOfContentsFor rdf:resource="{local:rdf-resource(.,'work')}"/>
			</bf:TableOfContents>
		</xsl:if>
	</xsl:template>		
	<!-- targetAudience -->
	<xsl:template match="mods:targetAudience[@valueURI]">
		<bf:intendedAudience rdf:resource="{@valueURI}"/>
	</xsl:template>
	<xsl:template match="mods:targetAudience">
		<!--IntendedAudience audience-->
		<!-- see bibframe example:http://bibframe.org:8282/vocab/IntendedAudience.html -->
		<bf:intendedAudience>
			<bf:IntendedAudience>
				<bf:audience><xsl:apply-templates/></bf:audience>
			</bf:IntendedAudience>
		</bf:intendedAudience>
	</xsl:template>
	
	<!-- Notes -->
	<xsl:template match="mods:note[@type='thesis']">
		<!-- NOTE: test dissertation note find examples -->
		<!-- NOTE: xql outputs thesis with 
        	element bf:dissertationInstitution {element bf:Organization {
                element bf:label {fn:string($d/marcxml:subfield[@code="c"])}}
                }
			element bf:dissertationIdentifier  { element bf:Identifier {
			     element bf:identifierValue{fn:string($d/marcxml:subfield[@code="o"])}			   
			     }
		-->
		<!-- Work -->
		<bf:dissertationNote>
			<xsl:value-of select="normalize-space(.)"/>
		</bf:dissertationNote>
	</xsl:template>
	<xsl:template match="mods:note[@type='acquisition']">
		<!-- Unspecified? -->
		<bf:immediateAcquisition>
			<xsl:apply-templates/>
		</bf:immediateAcquisition>
	</xsl:template>
	<xsl:template match="mods:note[@type='additional physical form']">
		<!-- Instance? -->
		<bf:otherPhysicalFormat>
			<xsl:apply-templates/>
		</bf:otherPhysicalFormat>
	</xsl:template>
	<xsl:template match="mods:note[@type='bibliography']">
		<!-- Unspecified? -->
		<bf:supplementaryContentNote>
			<xsl:apply-templates/>
		</bf:supplementaryContentNote>
	</xsl:template>
	<xsl:template match="mods:note[@type='creation/production credits']">
		<!-- Unspecified? -->
		<bf:creditsNote>
			<xsl:apply-templates/>
		</bf:creditsNote>
	</xsl:template>
	<xsl:template match="mods:note[@type='language']">
		<!-- Work? -->
		<bf:languageNote>
			<xsl:apply-templates/>
		</bf:languageNote>
	</xsl:template>
	<xsl:template match="mods:note[@type='ownership']">
		<!-- Instance -->
		<bf:custodialHistory>
			<xsl:apply-templates/>
		</bf:custodialHistory>
	</xsl:template>
	<xsl:template match="mods:note[@type='performers']">
		<!-- Unspecified -->
		<bf:performerNote>
			<xsl:apply-templates/>
		</bf:performerNote>
	</xsl:template>
	<xsl:template match="mods:note[@type='preferred citation']">
		<!-- Instance -->
		<bf:preferredCitation>
			<xsl:apply-templates/>
		</bf:preferredCitation>
	</xsl:template>
	<xsl:template match="mods:note[@type='reproduction']">
		<!-- Instance -->
		<bf:reproduction>
			<xsl:apply-templates/>
		</bf:reproduction>
	</xsl:template>
	<xsl:template match="mods:note[@type='restriction']">
		<bf:accessCondition>
			<xsl:apply-templates/>
		</bf:accessCondition>
	</xsl:template>
	<xsl:template match="mods:note[@type='statement of responsibility']">
		<bf:responsibilityStatement>
			<xsl:apply-templates/>
		</bf:responsibilityStatement>
	</xsl:template>
	<xsl:template match="mods:note">
		<bf:note><xsl:apply-templates/></bf:note>
	</xsl:template>
	
	<!-- Subjects -->
	<!-- NOTE mismatch in subject output hate to repeat all the code below... best way? function? template or parameter? -->
	<!-- Counting preceding siblings incorretly, outputs as agent1 not agent11 -->
	<xsl:template match="mods:subject">
		<xsl:param name="mode"/>
		<xsl:variable name="type">
			<xsl:choose>
				<xsl:when test="mods:topic"><xsl:text>topic</xsl:text></xsl:when>
				<xsl:when test="mods:geographic"><xsl:text>place</xsl:text></xsl:when>
				<xsl:when test="mods:temporal"><xsl:text>temporal</xsl:text></xsl:when>
				<xsl:when test="mods:titleInfo"><xsl:text>title</xsl:text></xsl:when>
				<!-- This one needs to check for name type -->
				<xsl:when test="mods:name">
					<xsl:choose>
						<xsl:when test="@type='family'">family</xsl:when>
						<xsl:when test="@type='personal'">person</xsl:when>
						<xsl:when test="@type='conference'">meeting</xsl:when>
						<xsl:when test=".[@type='corporate'] | .[@type='corporate' and .[mods:roleTerm[@type='code'] = 'dgg']]">organization</xsl:when>
						<xsl:otherwise>agent</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:when test="mods:geographicCode">place<xsl:text></xsl:text></xsl:when>
				<xsl:when test="mods:hierarchicalGeographic">place<xsl:text></xsl:text></xsl:when>
				<xsl:when test="mods:cartographics"><xsl:text>Cartography</xsl:text></xsl:when>
				<xsl:otherwise><xsl:text>topic</xsl:text></xsl:otherwise>
			</xsl:choose>			
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$mode = 'ref'">
				<bf:subject rdf:resource="{local:rdf-resource(.,$type)}"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:choose>
					<xsl:when test="mods:topic">
						<bf:Topic rdf:about="{local:rdf-resource(.,$type)}">
							<xsl:call-template name="subject-child"/>
							<xsl:call-template name="hasAuthority"/>
						</bf:Topic>
					</xsl:when>
					<xsl:when test="mods:geographic">
						<bf:Place rdf:about="{local:rdf-resource(.,$type)}">
							<xsl:call-template name="subject-child"/>
							<xsl:call-template name="hasAuthority"/>
						</bf:Place>
					</xsl:when>
					<xsl:when test="mods:temporal">
						<bf:Temporal rdf:about="{local:rdf-resource(.,$type)}">
							<xsl:call-template name="subject-child"/>
							<xsl:call-template name="hasAuthority"/>
						</bf:Temporal>
					</xsl:when>
					<!-- if child titleInfo create new work instance NOTE: should this just call titleInfo? Not sure why it is calling work -->
					<xsl:when test="mods:titleInfo">
						<xsl:call-template name="work"/>
					</xsl:when>
					<xsl:when test="mods:name">
						<xsl:apply-templates/>
					</xsl:when>
					<xsl:when test="mods:geographicCode">
						<bf:Place rdf:about="{local:rdf-resource(.,$type)}">
							<xsl:call-template name="subject-child"/>
							<xsl:call-template name="hasAuthority"/>
						</bf:Place>
					</xsl:when>
					<xsl:when test="mods:genre"/>
					<xsl:when test="mods:hierarchicalGeographic">
						<!-- WORK -->
						<!--NOTE: Use MODSRDF for hierarchicalGeographic and its subelements under bf:place -->
						<bf:place>
							<bf:Place>
								<xsl:choose>
									<xsl:when test="mods:hierarchicalGeographic/@authority">
										<bf:authorizedAccessPoint>
											<xsl:value-of select="string-join(mods:hierarchicalGeographic/child::*/text(),'--')"/>
										</bf:authorizedAccessPoint>							
									</xsl:when>
									<xsl:otherwise>
										<bf:label><xsl:value-of select="string-join(mods:hierarchicalGeographic/child::*/text(),'--')"/></bf:label>
									</xsl:otherwise>
								</xsl:choose>
								<xsl:choose>
									<xsl:when test="mods:hierarchicalGeographic/@authorityURI">
										<bf:hasAuthority rdf:resource="{mods:hierarchicalGeographic/@authorityURI}"/>
									</xsl:when>
									<xsl:otherwise>
										<bf:hasAuthority>
											<madsrdf:Authority>
												<!-- NOTE, where does this come from? rdf type? -->
												<rdf:type rdf:resource="http://www.loc.gov/mads/rdf/v1#ComplexSubject"/>
												<madsrdf:authoritativeLabel>
													<xsl:value-of select="string-join(mods:hierarchicalGeographic/child::*/text(),'--')"/>
												</madsrdf:authoritativeLabel>
												<!-- 
											Generate based on @authority value 
											https://github.com/wsalesky/marc2bibframe/blob/master/modules/module.MARCXML-2-MADSRDF.xqy
										-->
												<madsrdf:isMemberOfMADSScheme rdf:resource="http://id.loc.gov/authorities/subjects"/>
											</madsrdf:Authority>
										</bf:hasAuthority>
									</xsl:otherwise>
								</xsl:choose>
							</bf:Place>
						</bf:place>
						<!-- 
					Question, does each child element get broken out into a seperate bf:place?
				-->
					</xsl:when>
					<xsl:when test="mods:cartographics">
						<!--Cartography  -->
						<bf:Cartography rdf:about="{local:rdf-resource(.,$type)}">
							<xsl:apply-templates/>
							<xsl:call-template name="hasAuthority"/>
						</bf:Cartography>
					</xsl:when>
				</xsl:choose>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<!-- Cartographic child elements -->
	<xsl:template match="mods:coordinates">
		<bf:cartographicCoordinates><xsl:apply-templates select="text()"/></bf:cartographicCoordinates>
	</xsl:template>
	<xsl:template match="mods:scale">
		<bf:cartographicScale><xsl:apply-templates select="text()"/></bf:cartographicScale>
	</xsl:template>
	<xsl:template match="mods:projection">
		<bf:cartographicProjection><xsl:apply-templates select="text()"/></bf:cartographicProjection>
	</xsl:template>
	
	<xsl:template name="subject-child">
		<bf:authorizedAccessPoint><xsl:value-of select="normalize-space(string-join(child::*,'--'))"/></bf:authorizedAccessPoint>
		<bf:label><xsl:value-of select="normalize-space(string-join(child::*,'--'))"/></bf:label>
		<xsl:if test="@valueURI">
			<bf:hasAuthority rdf:resource="{@valueURI}"/>
		</xsl:if>
	</xsl:template>
	
	<!-- Classification -->
	<xsl:template match="mods:classification" mode="ref">
		<!--NOTE need universal code to construct internal refs -->
		<xsl:variable name="internal-ref" select="temp"></xsl:variable>
		<!-- NOTE: need to generate ref? -->
		<!-- Work -->
		<xsl:choose>
			<xsl:when test="@authority = 'ddc'">
				<!--NOTE need a test record with dewey classification, maybe a koha record? -->
				<bf:classificationDdc rdf:resource="{concat('http://dewey.info/class/',normalize-space(.),'/about')}"/>
			</xsl:when>
			<!-- NOTE this will cause an issue with spaces in classification, should it substring before space? needs testing -->
			<xsl:when test="@authority = 'lcc'">
				<bf:classificationLcc rdf:resource="{concat('http://id.loc.gov/authorities/classification/',normalize-space(.))}"/>
			</xsl:when>
			<!-- NOTE: this doesn't have a url, nor does the nlm ? -->
			<xsl:when test="@authority = 'nlm'">
				<bf:classificationNlm rdf:resource="{concat('http://nlm.example.org/classification/',normalize-space(.))}"/>
			</xsl:when>
			<!-- NOTE: this doesn't have a url maybe: http://udcdata.info/ -->
			<xsl:when test="@authority = 'udc'">
				<bf:classificationUdc rdf:resource="{concat('http://udc.example.org/classification/',normalize-space(.))}"/>
			</xsl:when>
			<xsl:otherwise>
				<bf:classification rdf:resource="{$internal-ref}"/>
			</xsl:otherwise>
		</xsl:choose>		
	</xsl:template>
	<xsl:template match="mods:classification">	
			<bf:Classification>
				<xsl:attribute name="rdf:about">
					<xsl:value-of select="local:rdf-resource(.,'')"/>
				</xsl:attribute>
				<xsl:if test="@authority">
					<xsl:choose>
						<xsl:when test="@authority = 'ddc'">
							<bf:classificationScheme>ddc</bf:classificationScheme>		
						</xsl:when>
						<xsl:when test="@authority = 'lcc'">
							<bf:classificationScheme>ddc</bf:classificationScheme>		
						</xsl:when>
						<xsl:when test="@authority = 'nlm'">
							<bf:classificationScheme>nlm</bf:classificationScheme>		
						</xsl:when>
						<xsl:when test="@authority = 'udc'">
							<bf:classificationScheme>udc</bf:classificationScheme>		
						</xsl:when>
						<xsl:otherwise>
							<bf:classificationScheme><xsl:value-of select="@authority"/></bf:classificationScheme>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:if>
				<bf:classificationNumber><xsl:value-of select="."/></bf:classificationNumber>
				<bf:label><xsl:value-of select="."/></bf:label>
				<xsl:if test="@edition">
					<bf:classificationEdition><xsl:value-of select="@edition"/></bf:classificationEdition>
				</xsl:if>
				<!-- type is uri does that mean rdf:resource or uri string? very confused -->
				<xsl:if test="@valueURI"><bf:classificationNumberUri rdf:resource="{@valueURI}"/></xsl:if>
			</bf:Classification>
	</xsl:template>
	
	<!-- Related Item -->
	<xsl:template match="mods:relatedItem" mode="ref">
		<xsl:variable name="type">
			<xsl:choose>
				<xsl:when test="@type='preceding'"><xsl:text>precededBy</xsl:text></xsl:when>
				<xsl:when test="@type='succeeding'"><xsl:text>succeededBy</xsl:text></xsl:when>
				<xsl:when test="@type='original'"><xsl:text>originalVersion</xsl:text></xsl:when>
				<xsl:when test="@type='host'"><xsl:text>partOf</xsl:text></xsl:when>
				<xsl:when test="@type='constituent'"><xsl:text>hasPart</xsl:text></xsl:when>
				<xsl:when test="@type='series'"><xsl:text>series</xsl:text></xsl:when>
				<xsl:when test="@type='otherVersion'"><xsl:text>otherEdition</xsl:text></xsl:when>
				<xsl:when test="@type='otherFormat'"><xsl:text>otherPhysicalFormat</xsl:text></xsl:when>
				<xsl:when test="@type='isReferencedBy'">
					<xsl:text>findingAidNote</xsl:text>
					<!--NOTE Is isReferencedBy broader than findingAidNote? (mw) -->
				</xsl:when>
				<xsl:when test="@type='reviewOf'"><xsl:text>reviewOf</xsl:text>
					<!--NOTE Is isReferencedBy broader than findingAidNote? (mw) -->
				</xsl:when>
			</xsl:choose>
		</xsl:variable>
		<xsl:choose>
			<!-- Checks for ref with no child elements -->
			<xsl:when test="not(mods:titleInfo) and @valueURI or @xlink:href">
				<xsl:element name="bf:{$type}" namespace="http://bibframe.org/vocab/">
					<xsl:attribute name="rdf:resource" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#" select="@valueURI | @xlink:href"/>
				</xsl:element>
			</xsl:when>
			<xsl:otherwise>
				<xsl:element name="bf:{$type}" namespace="http://bibframe.org/vocab/">
					<xsl:attribute name="rdf:resource" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#" select="local:rdf-resource(.,'relatedItem')"/>
				</xsl:element>
			</xsl:otherwise>
		</xsl:choose>	
	</xsl:template>
	
	<xsl:template match="mods:relatedItem">
		<xsl:call-template name="bibframe"/>
	</xsl:template>
	
	<!-- Identifiers -->
	<xsl:template match="mods:identifier">
		<!-- NOTE: There is a question about how local identifiers are handled. 
			 Current implementation:
			      <bf:local>
			         <bf:Identifier>
			            <bf:identifierValue>NOR 0201</bf:identifierValue>
			            <bf:identifierScheme rdf:resource="http://id.loc.gov/vocabulary/identifiers/local"/>
			            <bf:identifierQualifier>Norwich ID</bf:identifierQualifier>
			         </bf:Identifier>
			      </bf:local> 
			Should it be:
				<bf:identifier>
			      <bf:local>
			         <bf:Identifier>
			            <bf:identifierValue>NOR 0201</bf:identifierValue>
			            <bf:identifierScheme rdf:resource="http://id.loc.gov/vocabulary/identifiers/local"/>
			            <bf:identifierQualifier>Norwich ID</bf:identifierQualifier>
			         </bf:Identifier>
			      </bf:local>
			    </bf:identifier>   
		-->
		<!-- Property name -->
		<xsl:variable name="element-name">
			<xsl:choose>
				<xsl:when test="@type='ansi'">ansi</xsl:when>
				<xsl:when test="@type='coden'">coden</xsl:when>
				<xsl:when test="@type='doi'">doi</xsl:when>
				<xsl:when test="@type='ean'">ean</xsl:when>
				<xsl:when test="@type='hdl'">hdl</xsl:when>
				<xsl:when test="@type='isbn' and count(.) = 10">isbn10</xsl:when>
				<xsl:when test="@type='isbn' and count(.) = 13">isbn13</xsl:when>
				<xsl:when test="@type='isbn'">isbn</xsl:when>
				<xsl:when test="@type='issn'">issn</xsl:when>
				<xsl:when test="@type='ismn'">ismn</xsl:when>
				<xsl:when test="@type='iso'">iso</xsl:when>
				<xsl:when test="@type='isrc'">isrc</xsl:when>
				<xsl:when test="@type='issue number'">issueNumber</xsl:when>
				<xsl:when test="@type='lccn'">lccn</xsl:when>
				<xsl:when test="@type='matrix number'">matrixNumber</xsl:when>
				<xsl:when test="@type='music plate'">musicPlate</xsl:when>
				<xsl:when test="@type='music publisher'">musicPublisherNumber</xsl:when>
				<xsl:when test="@type='sici'">sici</xsl:when>
				<xsl:when test="@type='stocknumber'">stockNumber</xsl:when>
				<xsl:when test="@type='strn'">strn</xsl:when>
				<xsl:when test="@type='upc'">upc</xsl:when>
				<xsl:when test="@type='urn'">urn</xsl:when>
				<xsl:when test="@type='videorecording'">videorecordingNumber</xsl:when>
				<xsl:when test="@type='videorecording identifier'">videorecordingNumber</xsl:when>
				<xsl:when test="@type='local'">local</xsl:when>
				<xsl:when test="@type='isan'">isan</xsl:when>
				<xsl:when test="@type='issn-l'">issnL</xsl:when>
				<xsl:when test="@type='istc'">istc</xsl:when>
				<xsl:when test="@type='iswc'">isw</xsl:when>
				<xsl:otherwise>systemNumber</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:element name="{concat('bf:',$element-name)}">
			<bf:Identifier>
				<bf:identifierValue><xsl:value-of select="."/></bf:identifierValue>
				<xsl:if test="@type or @typeURI">
					<xsl:variable name="type">
						<xsl:choose>
							<xsl:when test="@type='videorecording'">videorecording-identifier</xsl:when>
							<xsl:otherwise><xsl:value-of select="replace(@type,' ','-')"/></xsl:otherwise>
						</xsl:choose>
					</xsl:variable>
					<bf:identifierScheme rdf:resource="{concat('http://id.loc.gov/vocabulary/identifiers/',$type)}"/>
				</xsl:if>
				<xsl:if test="@displayLabel">
					<bf:identifierQualifier><xsl:value-of select="@displayLabel"/></bf:identifierQualifier>
				</xsl:if>
				<xsl:if test="@invalid='yes'">
					<bf:identifierStatus>invalid</bf:identifierStatus>
				</xsl:if>
			</bf:Identifier>
			<!--NOTE: unclear how we decide what it rdf:resource and what is not
			<xsl:choose>
				<xsl:when test="@invalid='true' or contains(.,' ')">
					
				</xsl:when>
				<xsl:otherwise>
					<xsl:attribute name="rdf:resource" select="concat('http://id.loc.gov/vocabulary/identifiers/',$element-name,'/',.)"/>
				</xsl:otherwise>
			</xsl:choose>
			-->
		</xsl:element>
	</xsl:template>
	
	<!-- Location -->
	<xsl:template match="mods:location">	
		<xsl:apply-templates/>
	</xsl:template>
	
	<xsl:template match="mods:location/mods:physicalLocation">
		<!-- NOTE, what about xlink:href ? -->
		<xsl:if test="@type = 'current' or 'discovery' or 'former' or 'creation'">
			<!-- NOTE: should there be a rd:resource pointing to this name? agent, whatever? -->
			<bf:heldBy><xsl:value-of select="."/></bf:heldBy>
		</xsl:if>
		<!-- Mapping says nothing about @type authority or @authorityURI -->
		<xsl:if test="@valueURI">
			<!-- NOTE, that seems just wrong, a uri appended to id.loc.gov URI? -->
			<bf:heldBy rdf:resource="{concat('http://id.loc.gov/vocabulary/organizations/',@valueURI)}"/>
		</xsl:if>
	</xsl:template>
	<xsl:template match="mods:shelfLocator">
		<!-- bf:HeldItem -->
		<bf:shelfMark><xsl:value-of select="."/></bf:shelfMark>
	</xsl:template>	
	<xsl:template match="mods:location/mods:url">
		<!-- NOTE: <bf:HeldMaterial> -->
		<!-- NOTE, should this test for URL type?  -->
		<!-- NOTE, Russian lit has this mapping to table of contents, needs some research  -->
		<bf:electronicLocator><xsl:value-of select="."/></bf:electronicLocator>
	</xsl:template>	
	<xsl:template match="mods:location/mods:holdingSimple">
		<!-- NOTE, should this be contained by  HeldMaterial -->
		<xsl:apply-templates/>
	</xsl:template>

	
	<!--NOTE: duplicate
	<xsl:template match="mods:form">
		<bf:carrierCategory>
			<bf:Category>
				<xsl:if test="@type">
					<bf:categoryType><xsl:value-of select="."/></bf:categoryType>
				</xsl:if>
				<xsl:if test="@authority">
					<bf:categorySource><xsl:value-of select="."/></bf:categorySource>
				</xsl:if>
			</bf:Category>
		</bf:carrierCategory>
	</xsl:template>
	-->
	<xsl:template match="mods:subLocation">
		<bf:subLocation><xsl:value-of select="."/></bf:subLocation>
	</xsl:template>
	<xsl:template match="mods:electronicLocator">
		<bf:electronicLocator rdf:resource="."/>
	</xsl:template>
	<xsl:template match="mods:copyInformation/mods:note">
		<bf:copyNote><xsl:value-of select="."/></bf:copyNote>
	</xsl:template>
	<xsl:template match="mods:copyInformation/mods:enumerationAndChronology">	
		<bf:enumerationAndChronology><xsl:value-of select="."/></bf:enumerationAndChronology>
	</xsl:template>
	<xsl:template match="mods:holdingExternal"/>
	<xsl:template match="mods:accessCondition">	
		<bf:accessCondition><xsl:apply-templates select="text()"/></bf:accessCondition>
	</xsl:template>

	<!-- Record Info -->
	<xsl:template match="mods:recordInfo">
		<!-- Child of bf:Annotation -->
		<xsl:apply-templates/>
	</xsl:template>
	<xsl:template match="mods:recordInfo/mods:recordIdentifier"/>
	<xsl:template match="mods:recordContentSource">
		<!--  Parent Annotation-->
		<bf:descriptionSource>
			<xsl:attribute name="rdf:resource">
				<xsl:choose>
					<xsl:when test="@valueURI"><xsl:value-of select="@valueURI"/></xsl:when>
					<xsl:otherwise><xsl:value-of select="concat('http://id.loc.gov/vocabulary/organizations/',.)"/></xsl:otherwise>
				</xsl:choose>
			</xsl:attribute>
		</bf:descriptionSource>
	</xsl:template>
	<xsl:template match="mods:recordCreationDate">
		<bf:creationDate><xsl:value-of select="."/></bf:creationDate>
	</xsl:template>
	<xsl:template match="mods:recordChangeDate">
		<bf:changeDate><xsl:value-of select="."/></bf:changeDate>
	</xsl:template>
	<xsl:template match="mods:recordOrigin">
		<bf:generationProcess><xsl:value-of select="."/></bf:generationProcess>
		<bf:generationProcess>Converted from MODS to BIBFRAME using MODS_BIBFRAME.xsl (<xsl:value-of select="current-dateTime()"/>)</bf:generationProcess>
	</xsl:template>
	<xsl:template match="mods:languageOfCataloging">
		<bf:descriptionLanguage rdf:resource="{concat('http://id.loc.gov/vocabulary/languages/',mods:languageTerm)}"/>
	</xsl:template>
	<xsl:template match="mods:descriptionStandard">
		<bf:descriptionConventions>
			<xsl:attribute name="rdf:resource">
				<xsl:choose>
					<xsl:when test="@valueURI"><xsl:value-of select="@valueURI"/></xsl:when>
					<xsl:otherwise><xsl:value-of select="concat('http://id.loc.gov/vocabulary/descriptionConventions/',.)"></xsl:value-of></xsl:otherwise>
				</xsl:choose>
			</xsl:attribute>
		</bf:descriptionConventions>
	</xsl:template>
</xsl:stylesheet>