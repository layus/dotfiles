# coding: latin-1
from EMVCAPcore import hex2lint

# Copyright 2011, 2012
#   Philippe Teuwen <phil@teuwen.org>
#   Jean-Pierre Szikora <jean-pierre.szikora@uclouvain.be>
# Cette cr�ation est mise � disposition selon
# le Contrat Attribution-NoDerivs 2.0 Belgium
# disponible en ligne http://creativecommons.org/licenses/by-nd/2.0/be/
# ou par courrier postal � Creative Commons, 171 Second Street,
# Suite 300, San Francisco, California 94105, USA.


def MyConnectFoo(reader_match, debug=False):
    class ConnectFooClass():
        foo = True
        # Example of a Belgian debit card
        # using Belgian Vasco810
        # Application: A0000000048002 SecureCode Aut
        # M1 challenge=nothing, OTP=23790240
        # ./EMV-CAP.py -m1 -r foo:cap_be
        # M1 challenge=1234, OTP=23580039
        # ./EMV-CAP.py -m1 -r foo:cap_be 1234
        msgs_cap_be = {
          'T':
              0,
          'atr':
              '3B67000000000000009000',
          '00A4040007A0000000048002':
              '6F2E8407A0000000048002A5239F38039F35015F2D026672BF0C159F5501' +\
              '005F2C020056DF0709424B533035363030389000',
          '80A8000003830134':
              '770E82021000940808010100080404009000',
          '00B2010C00':
              '703E5A0967030405123456789F5F3401025F25030801015F240312123157' +\
              '1367030405123456789D1212221000002200009F5F280200569F42020978' +\
              '9F4401029000',
          '00B2040C00':
              '70589F560B0000FF000000000003FFFF8E0A000000000000000001008C1B' +\
              '9F02069F03069F1A0295055F2A029A039C019F37049F4C029F34038D1F8A' +\
              '029F02069F03069F1A0295055F2A029A039C019F37049F4C029F3403910A' +\
              '9000',
          '80AE800022000000000000000000000000000080000000000000000000000000' +\
          '00000000010002':
              '77269F2701809F3602005A9F2608513C1201B7DB02A09F100F06015603A4' +\
              '000007000300000100029000',
          '80AE00002E5A3300000000000000000000000000008000000000000000000000' +\
          '00000000000001000200000000000000000000':
              '77269F2701009F3602005A9F2608AB0862BD0B5A7B8C9F100F0601560325' +\
              'A00007010300000100029000',
          '80AE800022000000000000000000000000000080000000000000000000000000' +\
          '12340000010002':
              '77269F2701809F360200599F260894AB83B4EA4FCD879F100F06015603A4' +\
              '000007000300000100029000',
          '80AE00002E5A3300000000000000000000000000008000000000000000000000' +\
          '00001234000001000200000000000000000000':
              '77269F2701009F360200599F26086AC5D81B1BDE0C9A9F100F0601560325' +\
              'A00007010300000100029000',
        }
        # Example of a Belgian debit card
        # using Belgian Vasco810
        # forcing application...
        # Application: A0000000043060 MAESTRO
        # M1 challenge=nothing, OTP=53780079
        # ./EMV-CAP.py -m1 -r foo:maestro_be
        msgs_maestro_be = {
          'T':
              0,
          'atr':
              '3B701100FF',
          '00A4040007A0000000043060':
              '6F308407A0000000043060A52550074D41455354524F8701035F2D026672' +\
              'BF0C115F2C020056DF0709424B533035363635319000',
          '80A80000028300':
              '770E82023800940808010301100102019000',
          '00B2010C00':
              '703E5A0967031122334455662F5F3401015F25030902015F240313053157' +\
              '1367031122334455662D1305221000000200009F5F280200569F42020978' +\
              '9F4401029000',
          '00B2011400':
              '70788E120000000000000000420102044403410302009F0702FF009F0D05' +\
              'FC40F480009F0E0504100800009F0F05F868F498008F01049F080200028C' +\
              '1B9F02069F03069F1A0295055F2A029A039C019F37049F35019F34038D1C' +\
              '8A029F02069F03069F1A0295055F2A029A039C019F37049F340391089F4A' +\
              '01829000',
          '80AE800021000000000000000000000000000080000008000000000000000000' +\
          '000037000000':
              '77369F2701809F360212349F26081234567890ABCDEF9F101F0E015803A4' +\
              '984000000000000000FF0F000120000CD30000000000000000059000',
          '80AE00002A5A3100000000000000000000000000008000000800000000000000' +\
          '000000000000000000000000000000':
              '77369F2701009F360212349F260800000000000000009F101F0E01580324' +\
              '9C4000000000000000FF0F000120000CD30000000000000000009000',
        }
        # Example of a Belgian debit card
        # using Belgian Vasco810
        # forcing application...
        # Application: D056000666111010 BANCONTACT
        # M1 challenge=nothing, OTP=53780079
        # ./EMV-CAP.py -m1 -r foo:bancontact_be
        msgs_bancontact_be = {
          'T':
              0,
          'atr':
              '3B701100FF',
          '00A4040008D056000666111010':
              '6F468408D056000666111010A53A500A42414E434F4E544143548701019F' +\
              '38069F3501DF40015F2D026672BF0C1A9F4D021E055F2C020056DF070942' +\
              '4B53303536363531DF2A01FF9000',
          '80A800000483023700':
              '770E82021000940808010100080404009000',
          '00B2010C00':
              '703E5A0967031122334455662F5F3401015F25030902015F240313053157' +\
              '1367031122334455662D1305221000000200009F5F280200569F42020978' +\
              '9F4401029000',
          '00B2040C00':
              '70589F560B0000FF000000000003FFFF8E0A000000000000000001008C1B' +\
              '9F02069F03069F1A0295055F2A029A039C019F37049F4C029F34038D1F8A' +\
              '029F02069F03069F1A0295055F2A029A039C019F37049F4C029F3403910A' +\
              '9000',
          '80AE800022000000000000000000000000000080000008000000000000000000' +\
              '00000000000000':
              '77269F2701809F360212349F26081234567890ABCDEF9F100F06015603A4' +\
              '000007000300000000009000',
          '80AE00002E5A3100000000000000000000000000008000000800000000000000' +\
              '00000000000000000000000000000000000000':
              '77269F2701009F360212349F260800000000000000009F100F0601560324' +\
              '044007000300000000009000',
        }
        # Example of a Belgian VISA
        # using Belgian Vasco810
        # Application: A0000000038002 VisaRemAuthen
        # M1 challenge=nothing, OTP=19814125
        # ./EMV-CAP.py -m1 -r foo:visa_dpa_be
        msgs_visa_dpa_be = {
          'T':
              0,
          'atr':
              '3B67000000000000009000',
          '00A4040007A0000000038002':
              '6F388407A0000000038002A52D9F38039F35015F2D026672BF0C1F9F5501' +\
              '005F5502424542034454715F2C020056DF0709424B533035363030389000',
          '80A8000003830134':
              '770E82021000940808010100100202009000',
          '00B2010C00':
              '70345A0844541234567890125F34010157131234567890120919D1306201' +\
              '0101062800008F5F25030912015F24031306305F280200569000',
          '00B2021400':
              '70589F560B0000FF000000000003FFFF8E0A000000000000000001008C1B' +\
              '9F02069F03069F1A0295055F2A029A039C019F37049F4C029F34038D1F8A' +\
              '029F02069F03069F1A0295055F2A029A039C019F37049F4C029F3403910A' +\
              '9000',
          '80AE800022000000000000000000000000000080000000000000010101000000' +\
          '00000000010002':
              '77269F2701809F3602004B9F2608499FC380743A56ED9F100F06025703A4' +\
              '000007000300000100029000',
          '80AE00002E5A3300000000000000000000000000008000000000000001010100' +\
          '00000000000001000200000000000000000000':
              '77269F2701009F3602004B9F260806656B99762147A69F100F0602570325' +\
              '200007010300000100029000',
        }
        # Example of a Belgian VISA
        # using Belgian Vasco810
        # forcing application...
        # Application: A0000000031010 Visa Credit
        # M1 challenge=nothing, OTP=53780079
        # ./EMV-CAP.py -m1 -r foo:visa_be
        msgs_visa_be = {
          'T':
              0,
          'atr':
              '3B67000000000000009000',
          '00A4040007A0000000031010':
              '6F438407A0000000031010A5385004564953418701019F38095F2A029F15' +\
              '029F35015F2D026672BF0C1B5F5502424542034506635F2C020056DF0709' +\
              '424B533035363330309000',
          '80A800000783050000000037':
              '770E82021000940808010200100101009000',
          '00B2010C00':
              '70345A0845061122334455665F34010357134506112233445566D1210201' +\
              '0103088200300F5F25031008015F24031210315F280200569000',
          '00B2020C00':
              '707C9F420209789F4401025F201A4455504F4E542D4C414A4F49452F4A45' +\
              '414E20202020202020209F0802008C8C1B9F02069F03069F1A0295055F2A' +\
              '029A039C019F37049F4C029F34038D1F8A029F02069F03069F1A0295055F' +\
              '2A029A039C019F37049F4C029F3403910A9F1F1030313033303030383832' +\
              '3030303030309000',
          '00B2011400':
              '703A8E14000000000000000042014403410302031E031F039F0702FF009F' +\
              '0E0504100000009F0F05F868EC98009F0D05FC40EC00008F01079F4A0182' +\
              '9000',
          '80AE800022000000000000000000000000000080000008000000000000000000' +\
              '00000000000000':
              '77269F2701809F360212349F26081234567890ABCDEF9F100F06025703A4' +\
              '000007000300000000009000',
          '80AE00002E5A3100000000000000000000000000008000000800000000000000' +\
              '00000000000000000000000000000000000000':
              '77269F2701009F360212349F260800000000000000009F100F0602570324' +\
              '040007000300000000009000',
        }
        # Example of a French VISA
        # using Belgian Vasco810
        # Application: A0000000038002 VisaRemAuthen
        # M1 challenge=nothing, OTP=34656023
        # ./EMV-CAP.py -m1 -r foo:visa_dpa_fr
        msgs_visa_dpa_fr = {
          'T':
              0,
          'atr':
              '3B65000065046C9000',
          '00A4040007A0000000038002':
              '6F1D8407A0000000038002A51250095649534120417574685F2D04667265' +\
              '6E9000',
          '80A80000028300':
              '80061000080101009000',
          '00B2010C00':
              '70628C159F02069F03069F1A0295055F2A029A039C019F37048D178A029F' +\
              '02069F03069F1A0295055F2A029A039C019F37045A084533112233445566' +\
              '5F3401008E0A000000000000000001009F56118001FFFFFF000000000000' +\
              '0000000000009F5501009000',
          '80AE80001D000000000000000000000000000080000000000000010101000000' +\
          '0000':
              '771E9F2701809F360200109F2608CF17CD2F3F3690449F100706780A03A4' +\
              '80009000',
          '80AE00001F5A3300000000000000000000000000008000000000000001010100' +\
          '00000000':
              '771E9F2701009F360200109F260814C3CC3C78CA84ED9F100706780A0325' +\
              '80009000',
        }
        # Example of a French VISA without DPA
        # using Belgian Vasco810
        # Application: A0000000031010 Visa Credit
        # M1 challenge=nothing, OTP=102823328
        # ./EMV-CAP.py -m1 -r foo:visa_cleo_fr
        msgs_visa_cleo_fr = {
          'T':
              0,
          'atr':
              '3B6500002063CB6A00',
          '00A4040007A0000000031010':
              '6F368407A0000000031010A52B9F1101015F2D0266725004564953418701' +\
              '029F12095649534120434C454FBF0C0ADF60020B239F4D020B239000',
          '80A80000028300':
              '80167C0008020201100105010803030108010100180101009000',
          '00B2020C00':
              '701A5F25031101105F24031402285A0849721122334455665F3401109000',
          '00B2030C00':
              '70425F280202508C1B9F02069F03069F1A0295055F2A029A039C019F3704' +\
              '9F45029F4C088D1A8A029F02069F03069F1A0295055F2A029A039C019F37' +\
              '049F4C089F4A01829000',
          '80AE800027000000000000000000000000000080000000000000010101000000' +\
          '000000000000000000000000':
              '77219F2701809F360200039F2608107A6B38B2EDBE309F100A06550A03A4' +\
              '90000200009000',
          '80AE0000275A3300000000000000000000000000008000000000000001010100' +\
          '000000000000000000000000':
              '77219F2701009F360200039F2608FFEAE35F180EF3A19F100A06550A0325' +\
              '90000200009000',
        }
        # From http://crypto.hyperlink.cz/files/emv_side_channels_v1.pdf
        # NOT WORKING as we don't know IPB neither obtained OTP
        # ./EMV-CAP.py -m1 -r foo:visa_rosa_sk -v -d
        msgs_visa_rosa_sk = {
          'T':
              0,
          'atr':
              '3BE900008121455649535F494E46200678',
          '00A4040007A0000000032010':
              '6F258407A0000000032010A51A500D5649534120456C656374726F6E5F2D' +\
              '08736B6373656E64659000',
          '80A80000028300':
              '800A5C0008010500100102019000',
          '00B2010C00':
              # fake answer based on AIP, CDOL1, CDOL2 values known
              '70308C159F02069F03069F1A0295055F2A029A039C019F37048D178A029F' +\
              '02069F03069F1A0295055F2A029A039C019F37049000',
          '00B2020C00':
              '70049F5601009000',  # fake answer with IPB = 00
          '80AE80001D000000000000000000000000000080000000000000010101000000' +\
          '0000':
              '801D80000A7BE8144022536A2206330A03A0B8000A020000000000F5A6E0' +\
              '3E9000',
          '80AE00001F5A3300000000000000000000000000008000000000000001010100' +\
          '00000000':
              '801200000A40EFF4C582B9763106330A0321B8009000',
        }
        # From http://www.ru.nl/publish/pages/578936\
        #          /emv-cards_and_internet_banking_-_michael_schouwenaar.pdf
        # using ABN-AMRO e-dentifier2 device
        # Application: A0000000048002 SecureCode Aut
        # M1 challenge=24661140, OTP=34998891
        # ./EMV-CAP.py -m1 24661140 -r foo:cap_abnamro_nl
        msgs_cap_abnamro_nl = {
          'T':
              0,
          'atr':
              '3B',  # unknown
          '00A4040007A0000000048002':
              '6F258407A0000000048002A51A500E536563757265436F64652041757487' +\
              '01005F2D046E6C656E9000',
          '80A80000028300':
              '770A820210009404080101009000',
          '00B2010C00':
              '70608C219F02069F03069F1A0295055F2A029A039C019F37049F35019F45' +\
              '029F4C089F34038D0C910A8A0295059F37049F4C085A0A12345678901234' +\
              '5678905F3401018E0A000000000000000001009F5501809F560C00007FFF' +\
              'FFE00000000000009000',
          '80AE80002B000000000000000000000000000080000000000000000000002466' +\
          '11403400000000000000000000010002':
              '77299F2701809F360200429F2608C14D71DBAFA79FED9F10120012A50003' +\
              '020000000000000000000000FF9000',
          # TODO Actual input should be scrambled, how???
          '80AE80002B00000000000000000000000000008000000000000000000000661D' +\
          '7D593400000000000000000000010002':
              '77299F2701809F360200429F2608C14D71DBAFA79FED9F10120012A50003' +\
              '020000000000000000000000FF9000',
          '80AE00001D000000000000000000005A33800000000024661140000000000000' +\
          '0000':
              '77299F2701009F3602004E9F260896F166E11152A46B9F10120012250003' +\
              '420000000000000000000000FF9000',
          # Actual input for AAC contains empty UN!
          # but it probably doesn't matter...
          '80AE00001D000000000000000000005A33800000000000000000000000000000' +\
          '0000':
              '77299F2701009F3602004E9F260896F166E11152A46B9F10120012250003' +\
              '420000000000000000000000FF9000',
        }
        # Using random reader
        # Application: A0000000048002 SecureCode Aut
        # M1 challenge=nothing, OTP=07986951
        # ./EMV-CAP.py -m1 -r foo:cap_rabo1_nl
        msgs_cap_rabo1_nl = {
          'T':
              0,
          'atr':
              '3B6700002920006F789000',
          '00A4040007A0000000048002':
              '6F258407A0000000048002A51A500E536563757265436F64652041757487' +\
              '01005F2D046E6C656E9000',
          '80A80000028300':
              '770A820210009404080101009000',
          '00B2010C00':
              '70608C219F02069F03069F1A0295055F2A029A039C019F37049F35019F45' +\
              '029F4C089F34038D0C910A8A0295059F37049F4C085A0A67331122334455' +\
              '66774F5F3401088E0A000000000000000001009F5501C09F560C0700007F' +\
              'FFFF0000000000009000',
          '80AE80002B000000000000000000000000000080000000000000000000000000' +\
              '00003400000000000000000000010002':
              '77299F2701809F360200799F2608DF0705A00E3A9EF29F10120C10A50003' +\
              '040000000000000000000000FF9000',
          '80AE00001D000000000000000000005A33800000000000000000000000000000' +\
              '0000':
              '77299F2701009F360200799F26085F547081592117429F10120C10250003' +\
              '440000000000000000000000FF9000',
        }
        # Using random reader
        # Application: A0000000048002 SecureCode Aut
        # M2+TDS challenge=0530026806, OTP=08180460
        # ./EMV-CAP.py -m2 0530026806 -r foo:cap_rabo2_nl
        msgs_cap_rabo2_nl = {
          'T':
              0,
          'atr':
              '3B6700002920006F789000',
          '00A4040007A0000000048002':
              '6F258407A0000000048002A51A500E536563757265436F64652041757487' +\
              '01005F2D046E6C656E9000',
          '80A80000028300':
              '770A820210009404080101009000',
          '00B2010C00':
              '70608C219F02069F03069F1A0295055F2A029A039C019F37049F35019F45' +\
              '029F4C089F34038D0C910A8A0295059F37049F4C085A0A67331122334455' +\
              '66774F5F3401088E0A000000000000000001009F5501C09F560C0700007F' +\
              'FFFF0000000000009000',
          '80AE80002B000000000000000000000000000080000000000000000000000000' +\
              '00003400000000000000000000010002':
              '77299F2701809F3602007C9F26089CA5A4CA1651CE319F10120C10A50003' +\
              '040000000000000000000000FF9000',
          '80AE00001D000000000000000000005A33800000000000000000000000000000' +\
              '0000':
              '77299F2701009F3602007C9F260840A7D7456A50984A9F10120C10250003' +\
              '440000000000000000000000FF9000',
        }
        # From http://www.cl.cam.ac.uk/~sjm217/papers/fc09optimised.pdf
        # using NatWest card, NatWest reader?
        # Application: A0000000048002 SecureCode Aut
        # M1 challenge=12345678, OTP=4822527
        # ./EMV-CAP.py -m1 12345678 -r foo:cap_fc09_uk
        msgs_cap_fc09_uk = {
          'T':
              0,
          'atr':
              '3B',  # unknown
          '00A4040007A0000000048002':
              '6F108407A0000000048002A5055F2D02656E9000',
          '80A80000028300':
              '80061000080101009000',
          '00B2010C00':
              '70558E0A000000000000000001009F5501A09F561200001F00000000000F' +\
              'FFFF000000000080008C159F02069F03069F1A0295055F2A029A039C019F' +\
              '37048D178A029F02069F03069F1A0295055F2A029A039C019F37049000',
          '80AE80001D000000000000000000000000000080000000000000000000001234' +\
          '5678':
              '8012800042B7F9A572DA74CAFF06770A03A480009000',
          '80AE00001F5A3300000000000000000000000000008000000000000000000000' +\
          '12345678':
              '80120000424F1C597723C97D7806770A032580009000',
        }
        # From http://www.cl.cam.ac.uk/research/security/banking/nopin\
        #          /oakland10chipbroken.pdf
        # Application discovery with 1PAY.SYS.DDF01
        # ./EMV-CAP.py -L -r foo:pse_uk
        msgs_pse_uk = {
          'T':
              0,
          'atr':
              '3B',  # unknown
          '00A404000E315041592E5359532E4444463031':
              '6F1A840E315041592E5359532E4444463031A5088801025F2D02656E9000',
          '00B2011400':
              '7040611E4F07A000000029101050104C494E4B2020202020202020202020' +\
              '20870101611E4F07A0000000031010501056495341204445424954202020' +\
              '2020208701029000',
          '00A4040007A0000000031010':
              '6F258407A0000000031010A51A5010564953412044454249542020202020' +\
              '208701025F2D02656E9000',
        }
        # Example of a Portuguese citizen card (eID)
        # using Belgian Vasco810
        # Application: A0000000048002 SecureCode Aut
        # M1 challenge=nothing, OTP=8669448
        # ./EMV-CAP.py -m1 -r foo:eid_pt
        msgs_eid_pt = {
          'T':
              0,
          'atr':
              '3B7D95000080318065B08311C0A983009000',
          '00A4040007A0000000048002':
              '6F1E8407A0000000048002A513501143617274616F20446F204369646164' +\
              '616F9000',
          '80A80000028300':
              '770A820210009404080101009000',
          '00B2010C00':
              '70785F200E31323334353637382034205A41325F24030000005A08461248' +\
              '10001001925F3401008E0A000000000000000001009F561580007FFFFF00' +\
              '0000000000000000000000000000009F5501008C219F02069F03069F1A02' +\
              '95055F2A029A039C019F37049F35019F45029F4C089F34038D06910A8A02' +\
              '95059000',
          '80AE80002B000000000000000000000000000080000000000000000000000000' +\
          '00003400000000000000000000010002':
              '77299F2701809F360200049F26084908A95A2FC4F0FB9F10120110A50003' +\
              '040000000000000000000000FF9000',
          '80AE000011000000000000000000005A338000000000':
              '77299F2701009F360200049F260800CADCF78CEB66BF9F10120110250003' +\
              '440000000000000000000000FF9000',
        }
        # Example of a Lux card
        # using Belgian Vasco810
        # Note that Vasco810 fails displaying an OTP
        # ./EMV-CAP.py -m1 -r foo:maestro_lu
        msgs_maestro_lu = {
          'T':
              1,
          'atr':
              '3BFF1800FF8131FE45656311086601560011875001220620FE',
          '00A4040007A000000004306000':
              '6F268407A0000000043060A51B50074D61657374726F8701009F380C9F33' +\
              '039F1A029F35019F40059000',
          '80A800000D830B208000000034000000000000':
              '771282021800940C0802020008060600080B0B009000',
          '00B2020C00':
              '70258C189F02069F030695055F2A029A039C019F37049F4C089F45028D09' +\
              '91108A0295059F4C089000',
          '00B2060C00':
              '70165F24031503315A0A6707241234567890123F5F3401009000',
          '00B20B0C00':
              '70308E0A000000000000000001039F5507800100913E20109F56120000FF' +\
              'FFFFFFFF00000000000000FF00003E9F0702FF009000',
          '80AE800025000000000000000000000000800000000000000000000000000000' +\
              '0000000000000000000000':
              '771E9F2701009F360200029F260822FBF1F8FAE371979F10070091030038' +\
              '01049000',
          '80AE00001F000000000000000000000000000000005A33800000000000000000' +\
              '0000000000':  # fake
              '77009000',    # fake
        }

        def __init__(self, card='debit'):
            assert hasattr(self, 'msgs_' + card)
            self.msgs = getattr(self, 'msgs_' + card)

        def transmit(self, CAPDU):
            hexCAPDU = ''.join(["%02X" % i for i in CAPDU])
            if hexCAPDU in self.msgs:
                lintRAPDU = hex2lint(self.msgs[hexCAPDU])
                return (lintRAPDU[:-2], lintRAPDU[-2], lintRAPDU[-1])
            elif hexCAPDU == '80CA9F1700':
                # Get PIN Retry Counter
                return (hex2lint('9F170103'), 0x90, 0x00)
            elif hexCAPDU[:12] == '002000800824':
                # Verify PIN
                return ([], 0x90, 0x00)
            else:
                # File not found
                return ([], 0x6A, 0x82)

        def getATR(self):
            return hex2lint(self.msgs['atr'])

        T0_protocol = 1
        T1_protocol = 2

        def getProtocol(self):
            if self.msgs['T'] == 0:
                return self.T0_protocol
            elif self.msgs['T'] == 1:
                return self.T1_protocol
            else:
                raise

    if len(reader_match) > 4:
        return ConnectFooClass(reader_match[4:])
    else:
        return ConnectFooClass()
