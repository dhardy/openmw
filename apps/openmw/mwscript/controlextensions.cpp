
#include "statsextensions.hpp"

#include <components/compiler/extensions.hpp>

#include <components/interpreter/interpreter.hpp>
#include <components/interpreter/runtime.hpp>
#include <components/interpreter/opcodes.hpp>

#include "interpretercontext.hpp"

#include <iostream>

namespace MWScript
{
    namespace Control
    {
        class OpSetControl : public Interpreter::Opcode0
        {
                std::string mControl;
                bool mEnable;

            public:

                OpSetControl (const std::string& control, bool enable)
                : mControl (control), mEnable (enable)
                {}

                virtual void execute (Interpreter::Runtime& runtime)
                {
                    if (mEnable)
                        std::cout << "enable: " << mControl << std::endl;
                    else
                        std::cout << "disable: " << mControl << std::endl;
                }
        };

        const int numberOfControls = 7;

        const int opcodeEnable = 0x200007e;
        const int opcodeDisable = 0x2000085;

        const char *controls[numberOfControls] =
        {
            "playercontrols", "playerfighting", "playerjumping", "playerlooking", "playermagic",
            "playerviewswitch", "vanitymode"
        };

        void registerExtensions (Compiler::Extensions& extensions)
        {
            std::string enable ("enable");
            std::string disable ("disable");

            for (int i=0; i<numberOfControls; ++i)
            {
                extensions.registerInstruction (enable + controls[i], "", opcodeEnable+i);
                extensions.registerInstruction (disable + controls[i], "", opcodeDisable+i);
            }
        }

        void installOpcodes (Interpreter::Interpreter& interpreter)
        {
            for (int i=0; i<numberOfControls; ++i)
            {
                interpreter.installSegment5 (opcodeEnable+i, new OpSetControl (controls[i], true));
                interpreter.installSegment5 (opcodeDisable+i, new OpSetControl (controls[i], false));
            }
        }
    }
}
