public class BarCodeUtil {
    public String inputText { get; set; }

    public List<BarcodeBar> barcodeData {set;get {
        return generateCode128(inputText);
    }}

    public BarCodeUtil () {
        inputText = ApexPages.currentPage().getParameters().get('data');

    }
    
    // Patterns for Code 128B (For characters with ASCII values 32 to 127)
    private static List<String> code128BPatterns = new List<String>{
        '11011001100', // space (ASCII 32)
        '11001101100', // !
        '11001100110', // "
        '10010011000', // #
        '10010001100', // $
        '10001001100', // %
        '10011001000', // &
        '10011000100', // '
        '10001100100', // (
        '11001001000', // )
        '11001000100', // *
        '11000100100', // +
        '10110011100', // ,
        '10011011100', // -
        '10011001110', // .
        '10111001100', // /
        '10011101100', // 0
        '10011100110', // 1
        '11001110010', // 2
        '11001011100', // 3
        '11001001110', // 4
        '11011100100', // 5
        '11001110100', // 6
        '11101101110', // 7
        '11101001100', // 8
        '11100101100', // 9
        '11100100110', // :
        '11101100100', // ;
        '11100110100', // <
        '11100110010', // =
        '11011011000', // >
        '11011000110', // ?
        '11000110110', // @
        '10100011000', // A
        '10001011000', // B
        '10001000110', // C
        '10110001000', // D
        '10001101000', // E
        '10001100010', // F
        '11010001000', // G
        '11000101000', // H
        '11000100010', // I
        '10110111000', // J
        '10110001110', // K
        '10001101110', // L
        '10111011000', // M
        '10111000110', // N
        '10001110110', // O
        '11101110110', // P
        '11010001110', // Q
        '11000101110', // R
        '11011101000', // S
        '11011100010', // T
        '11011101110', // U
        '11101011000', // V
        '11101000110', // W
        '11100010110', // X
        '11101101000', // Y
        '11101100010', // Z
        '11100011010', // [
        '11101111010', // backslash
        '11001000010', // ]
        '11110001010', // ^
        '10100110000', // _
        '10100001100', // `
        '10010110000', // a
        '10010000110', // b
        '10000101100', // c
        '10000100110', // d
        '10110010000', // e
        '10110000100', // f
        '10011010000', // g
        '10011000010', // h
        '10000110100', // i
        '10000110010', // j
        '11000010010', // k
        '11001010000', // l
        '11110111010', // m
        '11000010100', // n
        '10001111010', // o
        '10100111100', // p
        '10010111100', // q
        '10010011110', // r
        '10111100100', // s
        '10011110100', // t
        '10011110010', // u
        '11110100100', // v
        '11110010100', // w
        '11110010010', // x
        '11011011110', // y
        '11011110110', // z
        '11110110110', // {
        '10101111000', // |
        '10100011110', // }
        '10001011110', // ~
        '10111101000', // DEL (ASCII 127)
        '10111100010', // FNC 3 (Function Code)
        '11110101000', // FNC 2 (Function Code)
        '11110100010', // Shift
        '10111011110', // Code C (Switch to Code 128C)
        '10111101110', // Code B (Stay in Code 128B)
        '11101011110', // FNC 4 (Function Code)
        '11110101110'  // FNC 1 (Function Code)
    };
    // Define the Code 128B patterns.

    
    // Start and Stop codes for Code 128B
    private static String startCodeB = '11010010000'; 
    private static String stopCode = '1100011101011';

    public static List<BarcodeBar> generateCode128(String input) {
        String encodedData = startCodeB; // Start with the start code
        
        Integer checksumValue = 104; // Start code B's value for checksum calculation
        
        for(Integer i = 0; i < input.length(); i++) {
            Integer charValue = (Integer) input.charAt(i);
            
            // Ensure character is within supported ASCII range
            if(charValue >= 32 && charValue <= 127) {
                Integer patternIndex = charValue - 32;
                encodedData += code128BPatterns[patternIndex];
                checksumValue += patternIndex * (i + 1);
            } else {
                System.debug('Character out of supported range: ' + input.charAt(i));
            }
        }
        
        // Calculate checksum (using mod operator in Apex)
        Integer checksumIndex = Math.mod(checksumValue, 103);
        encodedData += code128BPatterns[checksumIndex];
        
        // Append the stop code
        encodedData += stopCode;
        
        // Convert to barcode bars for drawing
        List<BarcodeBar> barcodeBars = new List<BarcodeBar>();
        Integer position = 0;
        
        for (Integer i = 0; i < encodedData.length(); i++) {
            BarcodeBar bar = new BarcodeBar();
            bar.isBlack = (encodedData.charAt(i) == 49);


            bar.width = 1;  // Adjust width based on desired size
            bar.position = position;
            
            position += bar.width; // Update the position for the next bar
            barcodeBars.add(bar);
        }
        
        return barcodeBars;
    }

    public class BarcodeBar {
        public Integer width { get; set; }
        public Boolean isBlack { get; set; }
        public Integer position { get; set; }
    }

    public String getSVGString() {
        String svgStart = '<div width="100%" height="20">';
        String svgEnd = '</div>';
        String svgContent = '';
        for(BarcodeBar bar : barcodeData) {
            String fillColor = bar.isBlack ? 'black' : 'white';
            svgContent += '<span style="BORDER-LEFT: ' + fillColor + ' 1px solid; DISPLAY: inline-block; HEIGHT: 50px"></span>';
            // svgContent += '<rect x="' + bar.position + '" y="0" width="' + bar.width + '" height="50" fill="' + fillColor + '" />';
        }
        
        // return svgStart + svgContent + svgEnd;
        return svgContent ;
    }

    public String getBase64SVG() {
        String svgString = getSVGString();
        return svgString;
    }
}