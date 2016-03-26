# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF

  # Manages both the global and document specific configuration options for HexaPDF.
  #
  # == Overview
  #
  # HexaPDF allows detailed control over many aspects of PDF manipulation. If there is a need to
  # use a certain default value somewhere, it is defined as configuration options so that it can
  # easily be changed.
  #
  # Some options are defined as global options because they are needed on the class level - see
  # GlobalConfiguration. Other options can be configured for individual documents as they allow to
  # fine-tune some behavior - see DefaultDocumentConfiguration.
  #
  # A configuration option name is dot-separted to provide a hierarchy of option names. For
  # example, io.chunk_size.
  class Configuration

    # Creates a new document specific Configuration object by merging the values into the default
    # configuration object.
    def self.with_defaults(values = {})
      DefaultDocumentConfiguration.merge(values)
    end


    # Creates a new Configuration object using the provided hash argument.
    def initialize(options = {})
      @options = options
    end

    # Returns +true+ if the given option exists.
    def key?(name)
      options.key?(name)
    end
    alias :option? :key?

    # Returns the value for the configuration option +name+.
    def [](name)
      options[name]
    end

    # Uses +value+ as the value for the configuration option +name+.
    def []=(name, value)
      options[name] = value
    end

    # Returns a new Configuration object containing the options from the given configuration
    # object (or hash) and this configuration object.
    #
    # If a key already has a value in this object, its value is overwritten by the one from
    # +config+. However, hash values are merged instead of being overwritten.
    def merge(config)
      config = (config.kind_of?(self.class) ? config.options : config)
      self.class.new(options.merge(config) do |_key, old, new|
                       old.kind_of?(Hash) && new.kind_of?(Hash) ? old.merge(new) : new
                     end)
    end

    # :call-seq:
    #   config.constantize(name, key = nil)                  -> constant or nil
    #   config.constantize(name, key = nil) {|name| block}   -> obj
    #
    # Returns the constant the option +name+ is referring to. If +key+ is provided and the value
    # of the option +name+ responds to +[]+, the constant to which +key+ refers is returned.
    #
    # If no constant can be found and no block is provided, +nil+ is returned. If a block is
    # provided it is called with the option name and its result will be returned.
    #
    #   config.constantize('encryption.aes')      #=> HexaPDF::Encryption::FastAES
    #   config.constantize('filter.map', :Fl)     #=> HexaPDF::Filter::FlateDecode
    def constantize(name, key = :__unset)
      data = self[name]
      data = data[key] if key != :__unset && data.respond_to?(:[])
      (data = ::Object.const_get(data) rescue nil) if data.kind_of?(String)
      data = yield(name) if block_given? && data.nil?
      data
    end

    protected

    # Returns the hash with the configuration options.
    attr_reader :options

  end

  # The default document specific configuration object.
  #
  # Modify this object if you want to globally change document specific options or if you want to
  # introduce new document specific options.
  #
  # The following options are provided:
  #
  # document.auto_decrypt::
  #    A boolean determining whether the document should be decrypted automatically when parsed.
  #
  #    If this is set to +false+ and the PDF document should later be decrypted, the method
  #    Encryption::SecurityHandler.set_up_decryption(document, decryption_opts) has to be called to
  #    set and retrieve the needed security handler. Note, however, that already loaded indirect
  #    objects have to be decrypted manually!
  #
  #    In nearly all cases this option should not be changed from its default setting!
  #
  # graphic_object.map::
  #    A mapping from graphic object names to graphic object factories.
  #
  #    See HexaPDF::Content::GraphicObject for more information.
  #
  # graphic_object.arc.max_curves::
  #    The maximum number of curves used for approximating a complete ellipse using Bezier curves.
  #
  #    The default value is 6, higher values result in better approximations but also take longer
  #    to compute. It should not be set to values lower than 4, otherwise the approximation of a
  #    complete ellipse is visibly false.
  #
  # image_loader.pdf.use_stringio::
  #    A boolean determining whether images specified via file names should be read into memory
  #    all at once using a StringIO object.
  #
  #    Since loading a PDF as image entails having the IO object from the image PDF around until
  #    the PDF document where it is used is written, there is the choice whether memory should be
  #    used to load the image PDF all at once or whether a File object is used that needs to be
  #    manually closed.
  #
  #    To avoid leaking file descriptors, using the StringIO is the default setting. If you set
  #    this option to +false+, it is strongly advised to use +ObjectSpace.each_object(File)+ (or
  #    +IO+ instead of +File) to traverse the list of open file descriptors and close the ones
  #    that have been used for PDF images.
  #
  # io.chunk_size::
  #    The size of the chunks that are used when reading IO data.
  #
  #    This can be used to limit the memory needed for reading or writing PDF files with huge
  #    stream objects.
  #
  # page.default_media_box::
  #    The media box that is used for new pages that don't define a media box. Default value is
  #    A4. See HexaPDF::Type::Page::PAPER_SIZE for a list of predefined paper sizes.
  #
  #    The value can either be a rectangle defining the paper size or a Symbol referencing one of
  #    the predefined paper sizes.
  #
  # parser.on_correctable_error::
  #    Callback hook when the parser encounters an error that can be corrected.
  #
  #    The value needs to be an object that responds to \#call(document, message, position) and
  #    returns +true+ if an error should be raised.
  #
  # sorted_tree.max_leaf_node_size::
  #    The maximum number of nodes that should be in a leaf node of a node tree.
  DefaultDocumentConfiguration =
    Configuration.new('document.auto_decrypt' => true,
                      'graphic_object.map' => {
                        arc: 'HexaPDF::Content::GraphicObject::Arc',
                        endpoint_arc: 'HexaPDF::Content::GraphicObject::EndpointArc',
                        solid_arc: 'HexaPDF::Content::GraphicObject::SolidArc',
                      },
                      'graphic_object.arc.max_curves' => 6,
                      'image_loader.pdf.use_stringio' => true,
                      'io.chunk_size' => 2**16,
                      'page.default_media_box' => :A4,
                      'parser.on_correctable_error' => proc { false },
                      'sorted_tree.max_leaf_node_size' => 64)

  # The global configuration object, providing the following options:
  #
  # color_space.map::
  #    A mapping from a PDF name (a Symbol) to a color space class (see Content::ColorSpace). If
  #    the value is a String, it should contain the name of a constant that contains a color space
  #    class.
  #
  #    Classes for the most often used color space families are implemented and readily available.
  #
  #    See PDF1.7 s8.6
  #
  # encryption.aes::
  #    The class that should be used for AES encryption. If the value is a String, it should
  #    contain the name of a constant to such a class.
  #
  #    See Encryption::AES for the general interface such a class must conform to and
  #    Encryption::RubyAES as well as Encryption::FastAES for implementations.
  #
  # encryption.arc4::
  #    The class that should be used for ARC4 encryption. If the value is a String, it should
  #    contain the name of a constant to such a class.
  #
  #    See Encryption::ARC4 for the general interface such a class must conform to and
  #    Encryption::RubyARC4 as well as Encryption::FastARC4 for implementations.
  #
  # encryption.filter_map::
  #    A mapping from a PDF name (a Symbol) to a security handler class (see
  #    Encryption::SecurityHandler). If the value is a String, it should contain the name of a
  #    constant to such a class.
  #
  #    PDF defines a standard security handler that is implemented
  #    (Encryption::StandardSecurityHandler) and assigned the :Standard name.
  #
  # encryption.sub_filter_map::
  #    A mapping from a PDF name (a Symbol) to a security handler class (see
  #    Encryption::SecurityHandler). If the value is a String, it should contain the name of a
  #    constant to such a class.
  #
  #    The sub filter map is used when the security handler defined by the encryption dictionary
  #    is not available, but a compatible implementation is.
  #
  # filter.flate_compression::
  #    Specifies the compression level that should be used with the FlateDecode filter. The level
  #    can range from 0 (no compression), 1 (best speed) to 9 (best compression, default).
  #
  # filter.map::
  #    A mapping from a PDF name (a Symbol) to a filter object (see Filter). If the value is a
  #    String, it should contain the name of a constant that contains a filter object.
  #
  #    The most often used filters are implemented and readily available.
  #
  #    See PDF1.7 s7.4.1, ADB sH.3 3.3
  #
  # image_loader::
  #    An array with image loader implementations. When an image should be loaded, the array is
  #    iterated in sequence to find a suitable image loader.
  #
  #    If a value is a String, it should contain the name of a constant that is an image loader
  #    object.
  #
  #    See the ImageLoader module for information on how to implement an image loader object.
  #
  # object.type_map::
  #    A mapping from a PDF name (a Symbol) to PDF object classes which is based on the /Type
  #    field. If the value is a String, it should contain the name of a constant that contains a
  #    PDF object class.
  #
  #    This mapping is used to provide automatic wrapping of objects in the Document#wrap method.
  #
  # object.subtype_map::
  #    A mapping from a PDF name (a Symbol) to PDF object classes which is based on the /Subtype
  #    field. If the value is a String, it should contain the name of a constant that contains a
  #    PDF object class.
  #
  #    This mapping is used to provide automatic wrapping of objects in the Document#wrap method.
  #
  # task.map::
  #    A mapping from task names to callable task objects. See Task for more information.
  GlobalConfiguration =
    Configuration.new('encryption.aes' => 'HexaPDF::Encryption::FastAES',
                      'encryption.arc4' => 'HexaPDF::Encryption::FastARC4',
                      'encryption.filter_map' => {
                        Standard: 'HexaPDF::Encryption::StandardSecurityHandler',
                      },
                      'encryption.sub_filter_map' => {
                      },
                      'filter.flate_compression' => 9,
                      'filter.map' => {
                        ASCIIHexDecode: 'HexaPDF::Filter::ASCIIHexDecode',
                        AHx: 'HexaPDF::Filter::ASCIIHexDecode',
                        ASCII85Decode: 'HexaPDF::Filter::ASCII85Decode',
                        A85: 'HexaPDF::Filter::ASCII85Decode',
                        LZWDecode: 'HexaPDF::Filter::LZWDecode',
                        LZW: 'HexaPDF::Filter::LZWDecode',
                        FlateDecode: 'HexaPDF::Filter::FlateDecode',
                        Fl: 'HexaPDF::Filter::FlateDecode',
                        RunLengthDecode: 'HexaPDF::Filter::RunLengthDecode',
                        RL: 'HexaPDF::Filter::RunLengthDecode',
                        CCITTFaxDecode: nil,
                        CCF: nil,
                        JBIG2Decode: nil,
                        DCTDecode: 'HexaPDF::Filter::DCTDecode',
                        DCT: 'HexaPDF::Filter::DCTDecode',
                        JPXDecode: 'HexaPDF::Filter::JPXDecode',
                        Crypt: nil,
                        Encryption: 'HexaPDF::Filter::Encryption',
                      },
                      'color_space.map' => {
                        DeviceRGB: 'HexaPDF::Content::ColorSpace::DeviceRGB',
                        DeviceCMYK: 'HexaPDF::Content::ColorSpace::DeviceCMYK',
                        DeviceGray: 'HexaPDF::Content::ColorSpace::DeviceGray',
                      },
                      'image_loader' => [
                        'HexaPDF::ImageLoader::JPEG',
                        'HexaPDF::ImageLoader::PNG',
                        'HexaPDF::ImageLoader::PDF',
                      ],
                      'object.type_map' => {
                        XRef: 'HexaPDF::Type::XRefStream',
                        ObjStm: 'HexaPDF::Type::ObjectStream',
                        Catalog: 'HexaPDF::Type::Catalog',
                        Pages: 'HexaPDF::Type::PageTreeNode',
                        Page: 'HexaPDF::Type::Page',
                        Filespec: 'HexaPDF::Type::FileSpecification',
                        EmbeddedFile: 'HexaPDF::Type::EmbeddedFile',
                        ExtGState: 'HexaPDF::Type::GraphicsStateParameter',
                        XXEmbeddedFileParameters: 'HexaPDF::Type::EmbeddedFile::Parameters',
                        XXEmbeddedFileParametersMacInfo: 'HexaPDF::Type::EmbeddedFile::MacInfo',
                        XXFilespecEFDictionary: 'HexaPDF::Type::FileSpecification::EFDictionary',
                        XXInfo: 'HexaPDF::Type::Info',
                        XXNames: 'HexaPDF::Type::Names',
                        XXResources: 'HexaPDF::Type::Resources',
                        XXTrailer: 'HexaPDF::Type::Trailer',
                        XXViewerPreferences: 'HexaPDF::Type::ViewerPreferences',
                      },
                      'object.subtype_map' => {
                        Image: 'HexaPDF::Type::Image',
                        Form: 'HexaPDF::Type::Form',
                      },
                      'task.map' => {
                        set_min_pdf_version: 'HexaPDF::Task::SetMinPDFVersion',
                        optimize: 'HexaPDF::Task::Optimize',
                        dereference: 'HexaPDF::Task::Dereference',
                      })

end