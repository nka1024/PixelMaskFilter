package starling.filters
{
    import flash.display3D.Context3D;
    import flash.display3D.Context3DProgramType;
    import flash.display3D.Program3D;
    import flash.geom.ColorTransform;

    import starling.filters.FragmentFilter;
    import starling.textures.Texture;

    /**
     * The PixelMaskFilter applies alpha mask to a display object.
     * Mask texture must have 0xFFFFFF foreground. Mask offset
     * can be set via maskX/maskY properties.
     *
     * @author Kirill Nepomnyaschiy
     */
    public class PixelMaskFilter extends FragmentFilter
    {
        public var maskX:int = 0;
        public var maskY:int = 0;

        private var _shaderProgram:Program3D;
        private var _maskTexture:Texture;

        private var _offsets:Vector.<Number> = new <Number>[0, 0, 0, 0];

        private var _maskAlpha:Number = 1.0;
        private var _colorOffset:Number = 1.0 / 255.0;
        private var _programConstVector:Vector.<Number> = new Vector.<Number>(4);
        private var _colorTransform:ColorTransform = new ColorTransform();

        public function PixelMaskFilter($maskTexture:Texture = null)
        {
            _maskTexture = $maskTexture;
        }

        public override function dispose():void
        {
            if (_shaderProgram) _shaderProgram.dispose();
            super.dispose();
        }

        protected override function createPrograms():void
        {
            var vertexShaderString:String =
                "m44 op, va0, vc0           \n" + // 4x4 matrix transform to output space
                "mov v0, va1                \n" + // pass texture coordinates to fragment program

                "mov vt0, va1               \n" +
                "add vt0.x, va1.x, vc4.x    \n" + // x offset
                "sub vt0.y, va1.y, vc4.y    \n" + // y offset
                "mov v1, vt0                \n"; // pass mask offset

            var fragmentShaderString:String =
                "tex ft0, v0, fs0 <2d,miplinear,linear,clamp>   \n" + // sample texture
                "mul ft0, ft0, fc0                              \n" + // mult with colorMultiplier
                "add ft0, ft0, fc1                              \n" + // mult with colorOffset
                "tex ft1, v1, fs1 <2d,miplinear,linear,clamp>   \n" + // sample mask

                "sub ft2, fc2, ft1                \n" + // (1 - maskcolor)
                "mov ft3, fc3                     \n" + // save maskalpha
                "sub ft3, fc2, ft3                \n" + // (1 - maskalpha)
                "mul ft3, ft2, ft3                \n" + // (1 - maskcolor) * (1 - maskalpha)
                "add ft3, ft1, ft3                \n" + // finalmaskcolor = maskcolor + (1 - maskcolor) * (1 - maskalpha));
                "mul oc, ft0, ft3                 \n";  // mult mask color with tex color and output it

            _shaderProgram = assembleAgal(fragmentShaderString, vertexShaderString);
        }


        protected override function activate(pass:int, context:Context3D, texture:Texture):void
        {
            updateParameters(texture.nativeWidth, texture.nativeHeight);

            // already set by super class:
            //
            // vertex constants 0-3: mvpMatrix (3D)
            // vertex attribute 0:   vertex position (FLOAT_2)
            // vertex attribute 1:   texture coordinates (FLOAT_2)
            // texture 0:            input texture

            context.setTextureAt(1, _maskTexture.base);
            context.setProgram(_shaderProgram);

            context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 4, _offsets);

            _programConstVector[0] = _colorTransform.redMultiplier;
            _programConstVector[1] = _colorTransform.greenMultiplier;
            _programConstVector[2] = _colorTransform.blueMultiplier;
            _programConstVector[3] = _colorTransform.alphaMultiplier;
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _programConstVector);

            _programConstVector[0] = _colorTransform.redOffset * _colorOffset;
            _programConstVector[1] = _colorTransform.greenOffset * _colorOffset;
            _programConstVector[2] = _colorTransform.blueOffset * _colorOffset;
            _programConstVector[3] = _colorTransform.alphaOffset * _colorOffset;
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, _programConstVector);

            _programConstVector[0] = 1.0;
            _programConstVector[1] = 1.0;
            _programConstVector[2] = 1.0;
            _programConstVector[3] = 1.0;
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, _programConstVector);

            _programConstVector[0] = _maskAlpha;
            _programConstVector[1] = _maskAlpha;
            _programConstVector[2] = _maskAlpha;
            _programConstVector[3] = _maskAlpha;
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, _programConstVector);
        }

        private function updateParameters(textureWidth:int, textureHeight:int):void
        {
            var pixelSizeX:Number = 1.0 / textureWidth;
            var pixelSizeY:Number = 1.0 / textureHeight;

            var offsetX:Number = pixelSizeX * maskX;
            var offsetY:Number = pixelSizeY * maskY;

            _offsets[0] = offsetX;
            _offsets[1] = offsetY;
            _offsets[2] = offsetX;
            _offsets[3] = offsetY;
        }

        override protected function deactivate(pass:int, context:Context3D, texture:Texture):void
        {
            context.setTextureAt(1, null);
        }
    }
}