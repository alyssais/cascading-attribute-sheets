# CAS - Cascading attribute sheets.
# Originally proposed by Tab Atkins (http://lists.w3.org/Archives/Public/public-webapps/2012JulSep/0508.html)
# This implementation by Alyssa Ross.

# This is the best method I have found for checking whether an object is an Array.
isArray = (object)-> (object? and object[0]? and object.length?) or object is []

# Contains a CAS selector, and calculates its specificity.
class CasSelector

  # Calculates the specificity of a selector.
  # Algorithim is from the CSS Selectors Level 3 W3C recommendation specification.
  # http://www.w3.org/TR/selectors/#specificity
  @calcSpecificity: (selector)->

    # Add a method to String to easily count the ocurrences.
    # Basically a wrapper for String.match().length
    String.prototype.countOccurrences = (regexp)->
      matches = @match regexp
      return matches.length if matches?
      return 0

    # ID selectors.
    a = selector.countOccurrences /#/g

    # Class selectors, attribute selectors and pseudo-classes.
    b = selector.countOccurrences /[\.|\[|:]]/g

    # Type selectors.
    # (Psuedo-elements are not supported in Cascading Attribute Sheets.)
    c = selector.countOccurrences /^[a-z|A-Z]|\s[a-z|A-Z]/g

    # Concatnate the numbers, rather than adding them,
    # then make them back into an integer.
    parseInt "#{a}#{b}#{c}", 10


  constructor: (selector)->
    @value = selector
    @specificity = CasSelector.calcSpecificity @value


# Contains a list of CAS properties applied to a single selector.
class CasDeclaration

  # @param CasSelector selector
  # @param Object properties - keys are property names, values are property values.
  constructor: (selector, properties)->
    properties  = {} if not properties

    @selector   = selector
    @properties = properties

  # Add a property to @properties.
  # Has two syntaxes:
  # 1. declaration.add "name", "value"
  # 2. declaration.add name: "value"
  # Syntax 2 allows adding of multiple properties at once,
  # while syntax 1 does not.
  add: (property, value)->
    if typeof property is "string" and typeof value is "string"
      # Using syntax 1

      @properties[property] = value

    else if typeof property is "object" and not value?
      # Using syntax 2

      @properties[propertyName] = property[propertyName] for propertyName of property

  # Remove specified properties from @list.
  # Takes an single string, or an array of strings, and removes every property name specfied.
  remove: (properties)->

    # We will be looping through the properties, so it must be an Array,
    # even if only one property is to be removed.
    # In JavaScript, and Array has a type of "object".
    properties = [properties] if typeof properties isnt "object"

    delete @properties[property] for property in properties

  # Removes the all properties from the declaration,
  # leaving it containing only a selector.
  removeAll: -> @properties = {}

# Contains a list of CasDeclarations, and adds extra methods.
class CasDeclarationList

  list = []

  # Takes either a single CasDeclaration, or an Array of them.
  # @param CasDeclaration|Array[CasDeclaration] declarations
  constructor: (declarations)->

    if declarations

      # If just a declaration was given rather than an Array,
      # wrap the declaration in an Array.
      declarations = [declarations] if not isArray declarations

      list = declarations

  # Provide a getter for the list.
  all: -> list

  # Allows the user to add new values to the array,
  # @param CasDeclaration|Array[CasDeclaration] declarations
  add: (declarations)->

    declarations = [declarations] if not isArray declarations

    # Merge the new declarations with @list.
    list = list.concat declarations

  # Sort the list according to the specificity of each selector.
  # @param Boolean reverse - If true, the list will be reversed.
  sort: (reverse)->

    # This will store the declarations in the correct order,
    # but the Array will be multi-dimensionsal.
    # We will sort it later.
    sorted = []

    for declaration in list

      # Set the specificity container to an empty array if it is not initialised.
      sorted[declaration.selector.specificity] = [] if not sorted[declaration.selector.specificity]

      # Store the declaration in the correct place.
      sorted[declaration.selector.specificity].push declaration

    # Flatten sorted.
    flattened = []

    for item in sorted

      # item could be an undefined placeholder.
      if isArray item
        for declaration in item
          flattened.push declaration

    # If the reverse argument is set to true, reverse the array.
    flattened = flattened.reverse() if reverse

    list = flattened


# This is the workhorse.
# Handles parsing of CAS,
# as well as applying attributes to HTML.
class CasCompiler

  # We don't need to do anything with the error (other than use console.error)
  # unless otherwise specified. So we just discard the error to begin with.
  # I should probably use Exceptions or try/catch or something, but meh.
  errorHandler = ->

  # Throws an error using errorHandler
  error = (message)->

    # Sooo useful!
    console.error message

    # Uses the error handler,
    # which is set when this class is implemented.

    errorHandler message

  # Setter for errorHandler.
  # Provides validation to make sure that error is a function.
  onerror: (error)->

    # Make sure error is a function.
    # If not, throw an error!
    if typeof error isnt "function"

      # We haven't overwritten the error handler yet,
      # so we can still the previous one.
      errorHandler "Not a function!"

      # Stop executing any further.
      return

    errorHandler = error

  # Compiling CAS from a String into Cas Objects,
  # which are implemented above.
  parse: (cas)->

    # Check that we haven't just been passed an empty file.
    if not cas
      error "Cas input is an empty string!"
      return

    # These are some helper methods to trim empty strings,
    # or strings containing only whitespace.
    Array.prototype.popEmpty   = -> @pop() while @length > 0 and not @[@length - 1].replace /\s/, ""
    Array.prototype.shiftEmpty = -> @shift() while @legnth > 0 and not @[0].replace /\s/, ""

    # As when using the String.trim method, whitespace-only items,
    # or empty strings, will only be removed from the "edges" of the Array,
    # not from the middle.
    Array.prototype.trim       = -> @popEmpty(); @shiftEmpty()

    # Declarationgs will be added later.
    # They need to be parsed first.
    declarations = new CasDeclarationList()

    # Before we go any further, strip commens.
    cas = cas.replace /\/\*(.*?)\*\//, ""

    # We can extract the declaration blocks by splitting with a closing brace,
    # as that is always how a block ends.
    cas = cas.split "}"

    # We need to remove the last item of the array because
    # we don't want anything after the last } if it is just
    # empty space. If it is not empty space, we should be able
    # to parse it anyway, like CSS does.
    cas.popEmpty()

    # Cas is now an Array of delcaration blocks as Strings,
    # each missing its closing brace.
    for declaration in cas

      # The selector is before the opening brace,
      # the properties are after.
      declaration = declaration.split "{"

      # Using Array.shift and Array.join is better than just Array[0] and Array[1],
      # because it means that if the user has needed to use an opening brace in an attribute value, for example,
      # it will still be recongised and not cause a compiler error.
      selector    = new CasSelector declaration.shift().trim()

      # Add the closing braces back in, in case they are needed.
      # Properties are seperated by semicolongs.
      properties  = declaration.join("{").trim().split ";"

      # There might be empty space after the last semicolon,
      # or it might be another property.
      # (AS with CSS, final semicolons are optional.)
      properties.popEmpty()

      # We are re-assigning the declaration variable, be careful!
      # Now that we have exracted the selector as a String,
      # we can convert it to a CasDeclaration,
      # which will calculate its specificity.
      declaration = new CasDeclaration selector # properties are not ready to add.

      # properties is now a String,
      # containing the property name,
      # a colon, and then the property value,
      for property in properties
        property = property.split ":"

        # There could be whitespace before the semi-colon.
        # Unlikely, though.
        property.popEmpty()

        # See above why Array.shift and Array.join are the bset way to do this.
        ###
        I decided to let extra colons be part of the property value,
        rather than the name, because the only reason you would want to use a colon
        in an attribute name in HTML is because you were using namespacing, which
        is illegal in HTML5.

        I am open for discussion on this, though.
        ###
        propertyName  = property.shift().trim()
        propertyValue = property.join(":").trim()

        declaration.add propertyName, propertyValue

      declarations.add declaration

    declarations.sort()
    return declarations

  # Finally! We can compile Cas!
  # This method takes some HTML as a String,
  # and some cas as a properly formatted CasDeclarationList.
  compile: (html, cas)->

    # When we parse the HTML later, the Doctype will not be preserved,
    # so we have to extract it here.
    # Since html.match returns an Array,
    # we will have to use an Array to hold the fallback as well,
    # and then exract the first item from whichever Array is used.
    doctype = (html.match /<\!doctype(.*?)>/i or ["<!doctype html>"])[0]

    # We create a brand new JavaScript document object,
    # and will fill it with the to-be-compiled html.
    # This allows the browser to parse it, so we don't have to!
    # (and it lets us use Node.querySelector later,
    # which would have been hell to write by hand.)
    container = document.implementation.createHTMLDocument()

    # container.documentElement is basically the <html> tag,
    # So you might think that we would end up with two nested <html> tags.
    # But in addition to the doctype, the <html> tag is stripped out anyway,
    # so two problems cancel each other out.
    container.documentElement.innerHTML = html

    for declaration in cas.all()

      # querySelector throws an exception if a selector is invalid.
      try

        # Find all occurrences of the selector in the HTML.
        matches = container.querySelectorAll declaration.selector.value

      catch e
        error e.message

      # Apply each attribute to each selector match.
      for element in matches
        for propertyName of declaration.properties
          propertyValue = declaration.properties[propertyName]
          element.setAttribute propertyName, propertyValue

    # Return the compiled HTML.
    doctype + container.documentElement.outerHTML
